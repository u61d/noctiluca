#!/usr/bin/env python3
"""records the real surface to a video, frame by frame at the real timing.

    python3 tests/capture_motion.py OUT.mp4 [--story=NAME] [--fps=60] [--scale=0.5]

needs pyside6, xvfb-run, mesa, ffmpeg, and g++ with qt6 headers to build tests/tools/capture.cpp
"""
import importlib.util
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEMPLATE = ROOT / "design" / "previews" / "motion.qml"
TOOL_SRC = ROOT / "tests" / "tools" / "capture.cpp"
CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "noctiluca"

HISTORY = ('Notifs.history = [ { appName: "firefox", summary: "Download finished", body: "arch.iso", '
           'time: new Date(), seen: true } ];')
TOAST = ('Notifs.popups = [ { appName: "discord", summary: "Jonas", body: "the new motion is so smooth", '
         'urgency: 1, expireTimeout: -1, actions: [], image: "", time: new Date() } ].concat(Notifs.popups);')
TOAST2 = ('Notifs.popups = [ { appName: "firefox", summary: "Download finished", body: "arch-2026.10.01-x86_64.iso", '
          'urgency: 1, expireTimeout: -1, actions: [], image: "", time: new Date() } ].concat(Notifs.popups);')

# (duration ms, [(at ms, js), ...])
def GO(n: int) -> str:
    """Switch the fixture monitor to workspace n, the way a Hyprland event would."""
    return (f"Hyprland.mon = Object.assign({{}}, Hyprland.mon, {{ activeWorkspace: {{ id: {n} }} }}); "
            f"Hyprland.focusedWorkspace = {{ id: {n} }};")


STORIES = {
    "panels": (5200, [
        (300, HISTORY + ' Panels.current = "control";'),
        (1500, 'Panels.current = "dashboard";'),
        (2700, 'Panels.current = "launcher";'),
        (3900, 'Panels.current = "";'),
    ]),
    "reduced": (4400, [
        (100, 'Settings.motion.reduce = true;'),
        (300, HISTORY + ' Panels.current = "control";'),
        (1300, 'Panels.current = "dashboard";'),
        (2300, 'Panels.current = "launcher";'),
        (3300, 'Panels.current = "control";'),
        (3900, 'Panels.current = "";'),
    ]),
    "close": (2400, [
        (200, HISTORY + ' Panels.current = "control";'),
        (1200, 'Panels.current = "";'),
    ]),
    "interrupt": (2600, [
        (200, HISTORY + ' Panels.current = "control";'),
        (1200, 'Panels.current = "";'),
        (1330, 'Panels.current = "control";'),
        (2000, 'Panels.current = "";'),
    ]),
    "touch": (2400, [
        (200, 'surface.pulseAt(1700, 20, 1.0);'),
        (700, 'surface.pulseAt(80, 18, 1.0);'),
        (1100, 'surface.pulseAt(960, 14, 0.8);'),
    ]),
    "lock": (3400, [
        (200, 'Session.lockRequested = true;'),
        (1500, 'lock.state.entered = "hunter";'),
        (1700, 'lock.state.entered = "hunter2";'),
        (2000, 'lock.state.entered = ""; lock.state.unlocking = true;'),
        (2500, 'Session.lockRequested = false; lock.state.unlocking = false;'),
    ]),
    "workspaces": (4000, [
        (300, GO(1)), (1100, GO(5)), (1900, GO(2)), (2700, GO(3)),
    ]),
    "toasts": (4200, [
        (300, TOAST),
        (1100, TOAST2),
        (2600, 'Notifs.popups = Notifs.popups.slice(1);'),
        (3300, 'Notifs.popups = [];'),
    ]),
}


def build_tool() -> Path:
    CACHE.mkdir(parents=True, exist_ok=True)
    exe = CACHE / "capture"
    if exe.exists() and exe.stat().st_mtime > TOOL_SRC.stat().st_mtime:
        return exe
    flags = subprocess.run(["pkg-config", "--cflags", "--libs", "Qt6Quick", "Qt6Qml", "Qt6Gui", "Qt6Core"],
                           capture_output=True, text=True)
    if flags.returncode != 0:
        sys.exit("capture_motion: Qt 6 development files not found (pkg-config Qt6Quick)")
    r = subprocess.run(["g++", "-O1", "-std=c++17", "-fPIC", str(TOOL_SRC), "-o", str(exe)] + flags.stdout.split(),
                       capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit("capture_motion: building the capture tool failed:\n" + r.stderr[-2000:])
    return exe


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        sys.exit(__doc__)
    out = Path(args[0]).resolve()
    opt = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    story = opt.get("story", "panels")
    fps = float(opt.get("fps", "60"))
    scale = float(opt.get("scale", "0.5"))
    duration, events = STORIES[story]

    import PySide6
    qt = Path(PySide6.__file__).parent / "Qt"
    exe = build_tool()

    spec = importlib.util.spec_from_file_location("rq", ROOT / "tests" / "render_qml.py")
    rq = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(rq)
    tmp = Path(tempfile.mkdtemp(prefix="noct-motion-"))
    qs, stubs = rq.build_tree(tmp)
    spec = importlib.util.spec_from_file_location("fx", ROOT / "tests" / "fixtures.py")
    fx = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(fx)
    fx.apply(stubs)
    for f in qs.rglob("*.qml"):
        body = f.read_text()
        new = re.sub(r"^\s*anchors\s*\{\s*(?:(?:top|bottom|left|right)\s*:\s*(?:true|false)\s*;?\s*)+\}\s*$",
                     "", body, flags=re.M)
        if new != body:
            f.write_text(new)

    timeline = ", ".join(f"[{ms}, function() {{ {js} }}]" for ms, js in events)
    scene = tmp / "motion.qml"
    template = ROOT / "design" / "previews" / "lockmotion.qml" if story.startswith("lock") else TEMPLATE
    scene.write_text(template.read_text().replace("@TIMELINE@", timeline))

    frames = tmp / "frames"
    frame_count = int(duration / 1000 * fps)
    env = {"PATH": "/usr/bin:/bin", "HOME": str(tmp), "LD_LIBRARY_PATH": str(qt / "lib"),
           "QT_PLUGIN_PATH": str(qt / "plugins"), "QT_QPA_PLATFORM": "xcb", "QSG_RHI_BACKEND": "opengl",
           "LIBGL_ALWAYS_SOFTWARE": "1", "GALLIUM_DRIVER": "llvmpipe", "QSG_RENDER_LOOP": "basic"}
    r = subprocess.run(["xvfb-run", "-a", "-s", "-screen 0 2560x1600x24", str(exe),
                        f"{tmp}:{stubs}:{qt / 'qml'}", str(scene), str(frames), str(frame_count), str(fps)],
                       capture_output=True, text=True, env=env, timeout=3600)
    noise = ("locale", "utf-8", "reconfigure", "more information")
    for line in (r.stdout + r.stderr).splitlines():
        if line.strip() and not any(n in line.lower() for n in noise):
            print("  " + line)
    if r.returncode != 0:
        return 1

    vf = f"scale=iw*{scale}:-2:flags=lanczos"
    if out.suffix == ".gif":
        cmd = ["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(fps), "-i", str(frames / "f%05d.png"),
               "-vf", vf + ",split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4",
               str(out)]
    else:
        cmd = ["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(fps), "-i", str(frames / "f%05d.png"),
               "-vf", vf, "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-preset", "slow", str(out)]
    subprocess.run(cmd, check=True)
    keep = opt.get("keep-frames")
    if keep:
        shutil.copytree(frames, keep, dirs_exist_ok=True)
    shutil.rmtree(tmp, ignore_errors=True)
    print(f"wrote {out}  ({frame_count} frames, {duration} ms, {fps:.0f} fps)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
