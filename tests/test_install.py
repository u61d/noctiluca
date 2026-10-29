#!/usr/bin/env python3
"""install.sh against a throwaway HOME. the installer won't run as root, so as root the parts
that need a real run are skipped.
"""
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INSTALL = ROOT / "install.sh"
IS_ROOT = os.geteuid() == 0
fails = []
ANSI = re.compile(r"\x1b\[[0-9;]*m")


def check(ok, label, detail=""):
    print(f"  [{'PASS' if ok else 'FAIL'}] {label}" + (f"  ({detail})" if detail else ""))
    if not ok:
        fails.append(label)


def skip(label, why):
    print(f"  [SKIP] {label}  ({why})")


class Home:
    def __init__(self, tmp: Path):
        self.home = tmp / "home"
        self.home.mkdir(parents=True, exist_ok=True)

    def run(self, *args, stdin=subprocess.DEVNULL):
        env = dict(os.environ)
        env.update({
            "HOME": str(self.home),
            "XDG_CONFIG_HOME": str(self.home / ".config"),
            "XDG_STATE_HOME": str(self.home / ".local" / "state"),
            "XDG_DATA_HOME": str(self.home / ".local" / "share"),
        })
        r = subprocess.run(["bash", str(INSTALL), *args], capture_output=True, text=True,
                           env=env, cwd=ROOT, stdin=stdin)
        r.clean = ANSI.sub("", r.stdout + r.stderr)
        return r

    def path(self, rel):
        return self.home / rel


def main() -> int:
    src = INSTALL.read_text()

    r = subprocess.run(["bash", str(INSTALL), "--list-packages"],
                       capture_output=True, text=True, cwd=ROOT)
    out = ANSI.sub("", r.stdout)
    check(r.returncode == 0 and "qt6-wayland" in out and "ttf-ibm-plex" in out,
          "--list-packages prints the package list")

    # CONFLICTS entries are name|reason on purpose, only check PACKAGES
    block = re.search(r"^PACKAGES=\((.*?)^\)", src, re.S | re.M)
    check(block is not None, "install.sh has a PACKAGES array")
    bad = [line.strip() for line in (block.group(1).splitlines() if block else [])
           if re.match(r'^\s*"[a-z0-9][a-z0-9.+-]*\|', line) and line.count("|") != 2]
    check(not bad, "every package entry has a group and a reason", str(bad[:2]))
    count = len(re.findall(r'^\s*"[a-z0-9][a-z0-9.+-]*\|', block.group(1) if block else "", re.M))
    check(count >= 40, f"the package list is complete ({count} packages)")

    # pacman would remove an aur build that may be someone else's desktop
    check('"quickshell|conflicts' in src, "the official `quickshell` package is on the refuse list")
    check("hyprlock" in src and "waybar" in src and "mako" in src,
          "the prebuilt widget packs the brief forbids are on the refuse list")

    r = subprocess.run(["bash", str(INSTALL), "--bogus"], capture_output=True, text=True, cwd=ROOT)
    check(r.returncode == 64, "an unknown argument exits 64", f"exit={r.returncode}")

    r = subprocess.run(["bash", str(INSTALL), "--help"], capture_output=True, text=True, cwd=ROOT)
    check(r.returncode == 0 and "--dry-run" in r.stdout, "--help lists the modes")

    if IS_ROOT:
        skip("install/uninstall behaviour", "running as root; install.sh refuses, by design")
        print()
        if fails:
            print(f"RESULT: {len(fails)} FAILED: {fails}")
            return 1
        print("RESULT: static install tests passed (behaviour tests skipped as root)")
        return 0

    tmp = Path(tempfile.mkdtemp(prefix="noct-install-"))
    h = Home(tmp)

    r = h.run("--dry-run", "--links", "--theme")
    before = sorted(p.name for p in h.home.rglob("*"))
    check(r.returncode == 0 and "would run" in r.clean, "--dry-run prints what it would do")
    check(before == [], "--dry-run created nothing in HOME", str(before[:3]))

    r = h.run("--yes", "--links", "--theme")
    check(r.returncode == 0, "install --links --theme succeeds", r.clean.strip()[-120:])
    expect = [".config/hypr", ".config/quickshell/noctiluca", ".config/kitty/kitty.conf",
              ".config/noctiluca/prompt.zsh", ".local/bin/noctiluca-shell",
              ".local/bin/noctiluca-wallpaper"]
    missing = [e for e in expect if not h.path(e).is_symlink()]
    check(not missing, "every config and script is linked into HOME", str(missing))
    check(h.path(".local/state/noctiluca/palette.json").is_file(), "a palette was generated")
    check(h.path(".config/kitty/noctiluca-colors.conf").is_file(), "themed files were rendered")

    zshrc = h.path(".zshrc")
    check(zshrc.is_file() and "noctiluca/prompt.zsh" in zshrc.read_text(),
          "the prompt line was added to .zshrc")

    stamp = {p: p.lstat().st_mtime for p in [h.path(e) for e in expect]}
    r = h.run("--yes", "--links", "--theme")
    unchanged = all(p.lstat().st_mtime == m for p, m in stamp.items())
    check(r.returncode == 0 and unchanged and r.clean.count("skip") >= len(expect),
          "a second run changes nothing and says so")
    check(zshrc.read_text().count("noctiluca/prompt.zsh") == 1,
          "the .zshrc line is not added twice")

    hypr = h.path(".config/hypr")
    hypr.unlink()
    hypr.mkdir()
    (hypr / "hyprland.conf").write_text("someone else's config\n")

    r = h.run("--links")          # no --yes, no terminal
    check(r.returncode == 0 and "refusing" in r.clean
          and (hypr / "hyprland.conf").is_file(),
          "without --yes and without a terminal, an existing config is LEFT ALONE")

    r = h.run("--yes", "--links")
    backups = list((h.home / ".local/state/noctiluca/backups").glob("*/hypr/hyprland.conf"))
    check(hypr.is_symlink() and backups,
          "with --yes the original is backed up, then replaced", str(backups[:1]))

    r = h.run("--uninstall")
    left = [e for e in expect if h.path(e).is_symlink()]
    check(r.returncode == 0 and not left, "--uninstall removes every link it made", str(left))
    check(backups and backups[0].is_file(), "--uninstall leaves the backups in place")

    print()
    if fails:
        print(f"RESULT: {len(fails)} FAILED: {fails}")
        return 1
    print("RESULT: all install tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
