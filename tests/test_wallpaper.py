#!/usr/bin/env python3
"""noctiluca-wallpaper against a throwaway HOME and XDG dirs. needs Pillow."""
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WP = ROOT / "scripts" / "noctiluca-wallpaper"
fails = []


def check(ok, label, detail=""):
    print(f"  [{'PASS' if ok else 'FAIL'}] {label}" + (f"  ({detail})" if detail else ""))
    if not ok:
        fails.append(label)


class Env:
    def __init__(self, tmp: Path):
        self.home = tmp / "home"
        self.state = tmp / "state"
        self.config = tmp / "config"
        self.walls = tmp / "walls"
        for d in (self.home, self.state, self.config, self.walls):
            d.mkdir(parents=True, exist_ok=True)

    @property
    def statefile(self) -> Path:
        return self.state / "noctiluca" / "wallpaper"

    @property
    def palette(self) -> Path:
        return self.state / "noctiluca" / "palette.json"

    def run(self, *args):
        env = dict(os.environ)
        env.update({
            "HOME": str(self.home),
            "XDG_STATE_HOME": str(self.state),
            "XDG_CONFIG_HOME": str(self.config),
            "NOCTILUCA_WALLPAPERS": str(self.walls),
        })
        return subprocess.run([sys.executable, "-I", str(WP), *args],
                              capture_output=True, text=True, env=env)


def image(path: Path, rgb, size=(160, 90)):
    from PIL import Image
    import random
    rnd = random.Random(sum(rgb) + size[0])
    im = Image.new("RGB", size, rgb)
    px = im.load()
    # flat colour quantizes to one bucket, add some texture
    for _ in range(size[0] * size[1] // 6):
        px[rnd.randrange(size[0]), rnd.randrange(size[1])] = tuple(
            min(255, c + rnd.randrange(50)) for c in rgb)
    im.save(path)
    return path


def main() -> int:
    try:
        import PIL  # noqa: F401
    except ImportError:
        print("  [SKIP] all wallpaper tests (python-pillow not installed)")
        return 0

    tmp = Path(tempfile.mkdtemp(prefix="noct-wp-"))
    e = Env(tmp)

    r = e.run("--list")
    try:
        doc = json.loads(r.stdout)
        ok = r.returncode == 0 and doc["schema"] == 1 and doc["wallpapers"] == []
    except (ValueError, KeyError):
        ok = False
    check(ok, "--list on an empty library is valid JSON with no entries")

    r = e.run("--current")
    check(r.returncode == 1 and r.stdout.strip() == "",
          "--current exits 1 and prints nothing when no wallpaper is set")

    r = e.run("--random")
    check(r.returncode == 1 and "no wallpapers found" in r.stderr,
          "--random with an empty library fails with the directories it looked in",
          r.stderr.strip()[:80])

    blue = image(e.walls / "harbour.png", (18, 72, 110))
    rust = image(e.walls / "kiln.jpg", (128, 64, 30))
    (e.walls / "notes.txt").write_text("not an image\n")
    (e.walls / "loop.mp4").write_bytes(b"\x00\x00\x00\x18ftypmp42" + bytes(64))
    (e.walls / "sub").mkdir()
    image(e.walls / "sub" / "nested.png", (40, 80, 40))

    r = e.run("--list")
    doc = json.loads(r.stdout)
    names = sorted(w["name"] for w in doc["wallpapers"])
    check(names == ["harbour", "kiln"], "--list finds images, skips non-images and subdirectories",
          str(names))
    check(all(w["current"] is False for w in doc["wallpapers"]),
          "nothing is marked current before anything is set")

    r = e.run("--set", str(e.walls / "loop.mp4"))
    check(r.returncode == 1 and "not a supported image" in r.stderr and not e.statefile.exists(),
          "--set refuses a video and leaves things as they were", r.stderr.strip()[:90])

    r = e.run("--set", str(blue))
    check(r.returncode == 0 and e.statefile.is_file()
          and e.statefile.read_text().strip() == str(blue.resolve()),
          "--set records the resolved path", r.stderr.strip()[:90])
    check(e.palette.is_file(), "--set regenerated palette.json")
    hue_blue = json.loads(e.palette.read_text())["hue"] if e.palette.is_file() else None
    check(hue_blue is not None and 180 <= hue_blue <= 290,
          "the palette hue came from the image (a blue one)", f"hue={hue_blue}")

    r = e.run("--list")
    doc = json.loads(r.stdout)
    cur = [w["name"] for w in doc["wallpapers"] if w["current"]]
    check(cur == ["harbour"], "--list marks the set wallpaper as current", str(cur))

    before = e.statefile.read_text(), e.palette.read_text()
    r = e.run("--set", str(blue))
    check(r.returncode == 0 and (e.statefile.read_text(), e.palette.read_text()) == before,
          "setting the same wallpaper twice changes nothing (idempotent)")

    r = e.run("--set", str(rust))
    hue_rust = json.loads(e.palette.read_text())["hue"]
    check(r.returncode == 0 and abs(hue_rust - hue_blue) > 40,
          "a different wallpaper produces a different hue", f"{hue_blue} -> {hue_rust}")

    good = e.statefile.read_text()
    r = e.run("--set", str(e.walls / "notes.txt"))
    check(r.returncode == 1 and "not a supported image" in r.stderr
          and e.statefile.read_text() == good,
          "--set on a non-image is refused and the current wallpaper is kept")

    r = e.run("--set", str(e.walls / "ghost.png"))
    check(r.returncode == 1 and "not a file" in r.stderr and e.statefile.read_text() == good,
          "--set on a missing file is refused")

    # the palette is built before the wallpaper is recorded, so an unreadable image never becomes it
    broken = e.walls / "broken.png"
    broken.write_bytes(b"\x89PNG\r\n\x1a\n" + b"garbage" * 20)
    r = e.run("--set", str(broken))
    check(r.returncode != 0 and e.statefile.read_text() == good,
          "an unreadable image does not become the wallpaper", f"exit={r.returncode}")

    before = e.statefile.read_text(), e.palette.read_text()
    r = e.run("--set", str(blue), "--dry-run")
    check(r.returncode == 0 and (e.statefile.read_text(), e.palette.read_text()) == before
          and "would record" in r.stdout,
          "--dry-run says what it would do and writes nothing")

    # broken.png is still there on purpose: --random has to skip it. without the retry this
    # failed about every other run
    current = e.statefile.read_text().strip()
    r = e.run("--random")
    check(r.returncode == 0 and e.statefile.read_text().strip() != current,
          "--random picks something other than the current wallpaper",
          r.stderr.strip()[:90])

    for _ in range(6):
        prev = e.statefile.read_text().strip()
        r = e.run("--random")
        if r.returncode != 0 or e.statefile.read_text().strip() == prev:
            break
    check(r.returncode == 0,
          "--random keeps working with an unreadable file in the library (6 more runs)",
          r.stderr.strip()[:90])

    only_bad = Path(tempfile.mkdtemp(prefix="noct-wp-bad-"))
    (only_bad / "a.png").write_bytes(b"\x89PNG\r\n\x1a\n" + b"junk" * 9)
    (only_bad / "b.png").write_bytes(b"\x89PNG\r\n\x1a\n" + b"junk" * 11)
    env = dict(os.environ)
    env.update({"HOME": str(e.home), "XDG_STATE_HOME": str(e.state),
                "XDG_CONFIG_HOME": str(e.config), "NOCTILUCA_WALLPAPERS": str(only_bad)})
    r = subprocess.run([sys.executable, "-I", str(WP), "--random"],
                       capture_output=True, text=True, env=env)
    check(r.returncode == 1 and "none of the" in r.stderr,
          "--random reports failure when no candidate works", r.stderr.strip()[-80:])

    print()
    if fails:
        print(f"RESULT: {len(fails)} FAILED: {fails}")
        return 1
    print("RESULT: all wallpaper tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
