#!/usr/bin/env python3
"""Drives the Mac on the bench board (Mini G + HDMI capture) in one process: mouse, keys, frames.

  hw_mac.py "STEP | STEP | ..."   steps run in order, then the frames taken are joined into one image

Steps:
  m DX DY [N]       mouse move, N times (default 1), button up
  d DX DY [N]       the same with the button down (a drag / a menu)
  up                the button up
  click             a click where the pointer is
  key KEYS          a key or chord of kg_board (alt+o, enter, ...)
  wait S            seconds
  shot NAME         a frame of /dev/video10 (640 x 360) into the output image
  load CORE         kg_board load
  MACRO             one of MACROS below

The pointer of the Mac moves with an acceleration of its own, so a path is only repeatable with
the same steps at the same rate: every move here is one AT line, delivered before the next. The
macros start from known places (the corner by "home", or where the macro before left the pointer)
and were measured on System 6.0.5 of Disk605.dsk (capture coordinates of 1280 x 720 in the notes).

Needs a bench ticket (hwq check before the call). Output: FRAMES (default scratch/hw.png).
"""
import os
import subprocess
import sys
import time

sys.path.insert(0, "/home/andy/Documents/Projects/Retrocomp/ZX-Spectrum/karabas-go/karabas-go-tools/board")
import kg_board as k  # noqa: E402

MACROS = {
    # the pointer to the menu bar over the Apple menu (from anywhere left of x ~ 100)
    "home": "m 0 -10 20",
    # Apple menu > Control Panel (from home): the General panel shows the time and PRAM settings
    "control_panel": "home | d 0 10 10 | d 0 9 4 | d 0 6 2 | up | wait 20",
    # Control Panel open, pointer where control_panel left it > the Fast radio of the insertion point
    "cp_fast": "m 10 0 76 | m 0 11 5 | m 0 3 | click",
    # from the Fast radio > Special menu > Shut Down
    "shutdown": "m -10 0 41 | m 0 -10 25 | d 0 10 23 | up | wait 15",
}

out = os.environ.get("FRAMES", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sim", "build", "hw.png"))
frames = []
port = None


def at(line, tries=4):
    global port
    for t in range(tries):
        try:
            if port is None:
                port = k.Port()
            port.at(line)
            port.at("AT+KARABAS=sync", k.SYNC_SECONDS)   # delivered, as kg_board does: the same rate
            return
        except Exception as e:          # the CDC port resets now and then with a core running
            port = None
            time.sleep(2)
    print("lost: " + line, file=sys.stderr)


def shot(name):
    f = os.path.join(os.path.dirname(out), "hw_%s.png" % name)
    subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-f", "v4l2", "-i", "/dev/video10",
                    "-vf", "select=gte(n\\,10),scale=640:360", "-frames:v", "1", f], check=True)
    frames.append(f)


def run(steps):
    for st in steps:
        w = st.split()
        if not w:
            continue
        c = w[0]
        if c in MACROS:
            run(MACROS[c].split("|"))
        elif c in ("m", "d"):
            n = int(w[3]) if len(w) > 3 else 1
            for _ in range(n):
                at("AT+KARABAS=mouse:%s,%s,%d" % (w[1], w[2], 1 if c == "d" else 0))
        elif c == "up":
            at("AT+KARABAS=mouse:0,0,0")
        elif c == "click":
            at("AT+KARABAS=mouse:0,0,1")
            at("AT+KARABAS=mouse:0,0,0")
        elif c == "key":
            at("AT+KARABAS=key:" + w[1])
        elif c == "wait":
            time.sleep(float(w[1]))
        elif c == "shot":
            shot(w[1])
        elif c == "load":
            port_close()
            subprocess.run([sys.executable, k.__file__, "load", w[1]], check=False)
        else:
            sys.exit("hw_mac.py: unknown step %r" % st)


def port_close():
    global port
    port = None


run(" ".join(sys.argv[1:]).split("|"))
if frames:
    from PIL import Image
    ims = [Image.open(f) for f in frames]
    w = Image.new("RGB", (640, 360 * len(ims)))
    for i, im in enumerate(ims):
        w.paste(im, (0, 360 * i))
    w.save(out)
    print(out)
