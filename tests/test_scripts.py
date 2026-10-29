#!/usr/bin/env python3
"""noctiluca-shell and noctiluca-ctl with fake qs, pkg-config, hyprctl and notify-send, so the
failure paths run without quickshell or hyprland.
"""
import os
import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHELL = ROOT / "scripts" / "noctiluca-shell"
CTL = ROOT / "scripts" / "noctiluca-ctl"
BUILD = ROOT / "scripts" / "build-quickshell.sh"
# the tests use a minimal PATH and subprocess looks the interpreter up in the child's
BASH = shutil.which("bash") or "/bin/bash"
fails = []


def check(ok, label, detail=""):
    print(f"  [{'PASS' if ok else 'FAIL'}] {label}" + (f"  ({detail})" if detail else ""))
    if not ok:
        fails.append(label)


def make_exe(path: Path, body: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("#!/bin/sh\n" + body)
    path.chmod(path.stat().st_mode | stat.S_IEXEC)


class Env:
    def __init__(self):
        self.home = Path(tempfile.mkdtemp(prefix="noct-sh-"))
        self.bin = self.home / "fakebin"
        self.log = self.home / "calls.log"
        self.bin.mkdir()
        # a system /usr/bin/qs must not leak in
        self.minbin = self.home / "minbin"
        self.minbin.mkdir()
        missing = []
        for tool in ("find", "sort", "tail", "head", "dirname", "cat", "sed", "grep", "mktemp"):
            src = shutil.which(tool)
            if src:
                (self.minbin / tool).symlink_to(src)
            else:
                missing.append(tool)
        assert not missing, f"coreutils missing from PATH: {missing}"
        self.base_path = str(self.minbin)

    def env(self, extra=None):
        e = {"HOME": str(self.home), "PATH": f"{self.bin}:{self.base_path}", "LOG": str(self.log)}
        e.update(extra or {})
        return e

    def run(self, script, *args, extra=None):
        return subprocess.run([BASH, str(script), *args], capture_output=True, text=True, env=self.env(extra))

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def private_qs_upstream_layout(self, version="0.3.2", stamp="6.12.0"):
        """Exactly what `cmake --install` produces: the binary is named `quickshell` and `qs`
        is a SYMLINK to it. This is the real layout on the user's machine."""
        prefix = self.home / ".local" / "opt" / f"quickshell-{version}"
        real = prefix / "bin" / "quickshell"
        make_exe(real, 'echo "qs $*" >> "$LOG"\n'
                       'if [ "$1" = "--version" ]; then echo "Quickshell %s (revision abc)"; fi\n'
                       'exit 0\n' % version)
        (prefix / "bin" / "qs").symlink_to("quickshell")
        if stamp is not None:
            (prefix / ".qt-version").write_text(stamp)
        return prefix

    def private_qs(self, version="0.3.2", stamp=None):
        prefix = self.home / ".local" / "opt" / f"quickshell-{version}"
        make_exe(prefix / "bin" / "qs", 'echo "qs $*" >> "$LOG"\nif [ "$1" = "--version" ]; then echo "Quickshell %s (revision abc)"; fi\nexit 0\n' % version)
        if stamp is not None:
            (prefix / ".qt-version").write_text(stamp)
        return prefix

    def install_config(self):
        d = self.home / ".config" / "quickshell" / "noctiluca"
        d.mkdir(parents=True, exist_ok=True)
        (d / "shell.qml").write_text("// test\n")


print("noctiluca-shell")

e = Env()
r = e.run(SHELL, "--check")
check(r.returncode == 69 and "no Quickshell found" in r.stderr, "no Quickshell at all -> exit 69 with advice",
      f"exit {r.returncode}: {r.stderr.strip()[:90]}")

e = Env()
make_exe(e.bin / "qs", 'echo "Quickshell 0.2.1 (revision 7511545ee20664e3b8b8d3322c0ffe7567c56f7a, distributed by AUR)"\n')
r = e.run(SHELL, "--check")
check(r.returncode == 69 and "predates Hyprland-Lua" in r.stderr, "YOUR situation: system qs 0.2.1 snapshot is refused", f"exit {r.returncode}")

e = Env()
make_exe(e.bin / "qs", 'echo "Quickshell 0.3.2 (revision x)"\n')
r = e.run(SHELL, "--check")
check(r.returncode == 0 and "fakebin/qs" in r.stdout, "system qs >= 0.3.2 is accepted")

e = Env()
e.private_qs("0.3.2", stamp="6.12.0")
make_exe(e.bin / "pkg-config", 'echo 6.12.0\n')
r = e.run(SHELL, "--check")
check(r.returncode == 0 and ".local/opt/quickshell-0.3.2/bin/qs" in r.stdout, "private build preferred; matching Qt stamp passes")

e = Env()
e.private_qs("0.3.2", stamp="6.12.0")
make_exe(e.bin / "pkg-config", 'echo 6.13.0\n')
r = e.run(SHELL, "--check")
check(r.returncode == 78 and "built against Qt 6.12.0" in r.stderr and "6.13.0" in r.stderr, "Qt ABI mismatch -> exit 78 naming both versions", f"exit {r.returncode}")
r = e.run(SHELL, "--check", extra={"NOCTILUCA_SKIP_QT_CHECK": "1"})
check(r.returncode == 0, "NOCTILUCA_SKIP_QT_CHECK=1 overrides the mismatch")

e = Env()
e.private_qs("0.3.2", stamp=None)
make_exe(e.bin / "pkg-config", 'echo 6.12.0\n')
r = e.run(SHELL, "--check")
check(r.returncode == 0 and "no .qt-version stamp" in r.stderr, "missing stamp only warns")

# upstream layout: `quickshell` plus a `qs` symlink. `find -type f` used to miss it
e = Env()
e.private_qs_upstream_layout("0.3.2")
make_exe(e.bin / "pkg-config", "echo 6.12.0\n")
make_exe(e.bin / "qs", 'echo "Quickshell 0.2.1 (revision 7511545, AUR)"\n')   # end-4's build
r = e.run(SHELL, "--print-qs")
check(r.returncode == 0 and ".local/opt/quickshell-0.3.2/bin/" in r.stdout,
      "upstream layout (qs is a SYMLINK) is found, not the old system qs", r.stdout.strip())
e.install_config()
e.log.write_text("")
r = e.run(SHELL)
check(r.returncode == 0 and e.calls() == ["qs -c noctiluca --no-duplicate"],
      "...and actually starts the shell", str(e.calls()))

e = Env()
prefix = e.private_qs_upstream_layout("0.3.2")
(prefix / "bin" / "qs").unlink()
make_exe(e.bin / "pkg-config", "echo 6.12.0\n")
r = e.run(SHELL, "--print-qs")
check(r.returncode == 0 and r.stdout.strip().endswith("/bin/quickshell"),
      "private build found even without the `qs` symlink", r.stdout.strip())

e = Env()
e.private_qs("0.3.2", stamp="6.12.0")
e.private_qs("0.3.10", stamp="6.12.0")
make_exe(e.bin / "pkg-config", 'echo 6.12.0\n')
r = e.run(SHELL, "--print-qs")
check("quickshell-0.3.10" in r.stdout, "newest private build wins (version sort: 0.3.10 > 0.3.2)", r.stdout.strip())

e = Env()
e.private_qs("0.3.2", stamp="6.12.0")
make_exe(e.bin / "pkg-config", 'echo 6.12.0\n')
r = e.run(SHELL)
check(r.returncode == 66 and "shell config not installed" in r.stderr, "shell not installed yet -> exit 66")
e.install_config()
r = e.run(SHELL)
check(r.returncode == 0 and e.calls() == ["qs -c noctiluca --no-duplicate"], "start = `qs -c noctiluca --no-duplicate`", str(e.calls()))
e.log.write_text("")
r = e.run(SHELL, "ipc", "call", "lock", "lock")
check(e.calls() == ["qs ipc -c noctiluca call lock lock"], "ipc call is routed with -c noctiluca", str(e.calls()))
r = e.run(SHELL, "bogus")
check(r.returncode == 64, "unknown argument -> exit 64")

print("noctiluca-ctl")

e = Env()
make_exe(e.bin / "hyprctl", 'echo "hyprctl $*" >> "$LOG"\n[ "$1" = "globalshortcuts" ] && echo "noctiluca:launcher : launcher"\nexit 0\n')
make_exe(e.bin / "notify-send", 'echo "notify $*" >> "$LOG"\n')
r = e.run(CTL, "lock")
check(r.returncode == 1 and "screen NOT locked" in r.stderr, "lock with the shell down refuses and says so", f"exit {r.returncode}")
check(any(c.startswith("notify") for c in e.calls()), "...and raises a notification")
check(not any("dispatch" in c for c in e.calls()), "...and never dispatches")

e = Env()
make_exe(e.bin / "hyprctl", 'echo "hyprctl $*" >> "$LOG"\n[ "$1" = "globalshortcuts" ] && echo "noctiluca:lock : lock"\nexit 0\n')
r = e.run(CTL, "lock")
check(r.returncode == 0 and 'hyprctl dispatch hl.dsp.global("noctiluca:lock")' in e.calls(), "lock with the shell up dispatches the Lua expression", str(e.calls()))
e.log.write_text("")
r = e.run(CTL, "dpms", "off")
check('hyprctl dispatch hl.dsp.dpms({ action = "off" })' in e.calls(), "dpms off -> Lua dispatcher expression", str(e.calls()))
r = e.run(CTL, "dpms", "sideways")
check(r.returncode == 64, "dpms rejects other arguments")

def doctor_env(owner_pid, owner_comm):
    d = Env()
    for tool in ("id", "tr", "xargs", "basename"):
        (d.minbin / tool).symlink_to(shutil.which(tool))
    make_exe(d.bin / "pgrep", 'case "$*" in *polkit*) exit 1 ;; esac\necho 4242\n')
    make_exe(d.bin / "busctl", f'echo PID={owner_pid}\necho Comm={owner_comm}\necho CommandLine={owner_comm}\n')
    make_exe(d.bin / "hyprctl", 'exit 0\n')
    return d

d = doctor_env(777, "mako")
r = d.run(CTL, "doctor")
check(r.returncode == 0 and "belongs to mako (pid 777)" in r.stdout and "kill 777" in r.stdout,
      "doctor names the program holding the notification name", r.stdout[-200:] if r.returncode else "")
d = doctor_env(4242, "quickshell")
r = d.run(CTL, "doctor")
check(r.returncode == 0 and "the shell owns org.freedesktop.Notifications" in r.stdout,
      "doctor recognises the shell as the owner")

m = Env()
for tool in ("id", "awk"):
    (m.minbin / tool).symlink_to(shutil.which(tool))
make_exe(m.bin / "pgrep", f'case "$*" in *-P*) exit 1 ;; esac\necho {os.getpid()}\n')
r = m.run(CTL, "mem")
check(r.returncode == 0 and "in use (PSS)" in r.stdout and " MB" in r.stdout and "threads" in r.stdout,
      "mem reports the shell's memory", (r.stdout + r.stderr).strip()[-160:])
make_exe(m.bin / "pgrep", "exit 1\n")
r = m.run(CTL, "mem")
check(r.returncode != 0 and "isn't running" in r.stderr, "mem with the shell down says so")

print("build-quickshell.sh")

e = Env()
# with the minimal PATH nothing is found, so the missing-deps path always runs
r = e.run(BUILD, "--check-deps")
check(r.returncode != 0 and "cmake" in r.stderr,
      "with deps missing: names them and exits non-zero",
      r.stderr.strip().splitlines()[0][:70] if r.stderr else "")
check("sudo pacman -S --needed" in r.stderr, "...and gives the exact pacman line to fix it")

real = subprocess.run([BASH, str(BUILD), "--check-deps"], capture_output=True, text=True)
if real.returncode == 0:
    check("all build dependencies present" in real.stdout and "Qt version:" in real.stdout,
          "with deps present: reports success and the Qt version",
          real.stdout.strip().splitlines()[-1][:60])
else:
    check("sudo pacman -S --needed" in real.stderr,
          "with deps present: (this machine is missing some) names them",
          real.stderr.strip().splitlines()[0][:60])

r = e.run(BUILD, "--bogus-flag")
check(r.returncode == 64, "unknown argument -> exit 64")

r = e.run(BUILD, "--help")
check(r.returncode == 0 and "private" in r.stdout.lower(), "--help explains why the build is private")

# checked against quickshell v0.3.2's CMakeLists.txt
src = BUILD.read_text()
for flag in ("-DCRASH_HANDLER=OFF", "-DX11=OFF", "-DI3=OFF",
             "-DUSE_JEMALLOC=ON",
             "-DCMAKE_BUILD_TYPE=Release"):
    check(flag in src, f"build flag present: {flag}")
for needed in ("WAYLAND", "HYPRLAND", "SERVICE_MPRIS", "SERVICE_PAM", "SERVICE_NOTIFICATIONS",
               "BLUETOOTH", "NETWORK", "SERVICE_PIPEWIRE", "SERVICE_UPOWER",
               "WAYLAND_SESSION_LOCK", "SERVICE_STATUS_NOTIFIER", "SCREENCOPY",
               "SCREENCOPY_HYPRLAND_TOPLEVEL", "SERVICE_POLKIT", "SERVICE_GREETD"):
    check(f"-D{needed}=OFF" not in src, f"feature left enabled (the shell needs it): {needed}")
check(".qt-version" in src, "writes the Qt ABI stamp that noctiluca-shell checks")
check("polkit\\n" in src and "screencopy\\n" in src and "greetd\\n" in src, "records screencopy, polkit and greetd in .noctiluca-features")

print()
if fails:
    print(f"RESULT: {len(fails)} FAILED: {fails}")
    sys.exit(1)
print("RESULT: all script tests passed")
