#!/usr/bin/env python3
"""mutation tests for hl_harness.lua: inject one mistake into a copy of config/hypr and expect the
harness to catch it.

    python3 tests/test_harness.py [--lua /path/to/lua5.5] [--stubs /path/to/hl.meta.lua]
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "config" / "hypr"
HARNESS = ROOT / "tests" / "hl_harness.lua"


def opt(name, default):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


LUA = opt("--lua", shutil.which("lua5.5") or shutil.which("lua") or "lua")
STUBS = opt("--stubs", "/usr/share/hypr/stubs/hl.meta.lua")

# (name, file, old, new, expected substring)
MUTATIONS = [
    ("spring uses `damping` (wrong for v0.56.2)", "modules/curves.lua", "dampening = s.dampening", "damping = s.dampening", "dampening"),
    ("blur size out of range", "modules/decoration.lua", "size = 5,", "size = 500,", "above the maximum"),
    ("float given to an integer option", "modules/decoration.lua", "rounding_power = 2,", "rounding = 12.5,", "expected Int"),
    ("typo in config section", "modules/decoration.lua", "blur = {", "blurr = {", "unknown config option"),
    ("typo in config key", "modules/input.lua", "follow_mouse = 1,", "follow_mous = 1,", "did you mean"),
    ("invalid string choice", "modules/input.lua", 'accel_profile = "flat"', 'accel_profile = "flatt"', "one of"),
    ("env value not a string", "modules/env.lua", 'hl.env("XCURSOR_SIZE", tostring(S.cursor_size))', "hl.env(\"XCURSOR_SIZE\", S.cursor_size)", "must be a string"),
    ("unknown bind option", "modules/keybinds.lua", "{ locked = true }", "{ lockd = true }", "unknown option"),
    ("duplicate bind", "modules/keybinds.lua", 'mod .. " + Y",', 'mod .. " + Q",', "duplicate"),
    ("unknown dispatcher", "modules/keybinds.lua", "hl.dsp.window.pin()", "hl.dsp.window.pinn()", "does not exist"),
    ("bad dispatcher argument", "modules/keybinds.lua", 'mode = "maximized"', 'mode = "maximised"', "mode must be"),
    ("bad focus direction", "modules/keybinds.lua", '{ "h", "left" }', '{ "h", "leftt" }', "direction must be"),
    ("shortcut missing from the contract", "modules/keybinds.lua", 'shell("launcher")', 'shell("laucher")', "not in tokens.json"),
    ("submap entered but never defined", "modules/keybinds.lua", 'hl.dsp.submap("resize"), "Resize: enter', 'hl.dsp.submap("resise"), "Resize: enter', "never defined"),
    ("one-shot submap", "modules/keybinds.lua", 'hl.define_submap("resize", function()', 'hl.define_submap("resize", "reset", function()', "one-shot"),
    ("animation leaf typo", "modules/animations.lua", 'bez("fadeIn",', 'bez("fadeInn",', "unknown leaf"),
    ("animation uses curve=", "modules/animations.lua", "bezier = \"noct-\" .. curve,", "curve = \"noct-\" .. curve,", "not accepted"),
    ("animation style invalid for leaf", "modules/animations.lua", '"popin 96%"', '"fade"', "style"),
    ("curve not defined", "modules/animations.lua", 'bez("global", "settle", "base")', 'bez("global", "setle", "base")', "not defined"),
    ("bezier out of range", "design/tokens.json", '"points": [0.34, 1.45, 0.64, 1.0]', '"points": [0.34, 3.45, 0.64, 1.0]', "outside"),
    ("layer rule effect typo", "modules/rules.lua", "surface    = { no_anim = true },", "surface    = { no_anim = true, blurr = true },", "unknown effect"),
    ("layer without policy", "design/tokens.json", '"prompt", "capture"]', '"prompt", "capture", "dock"]', "no policy for shell layer"),
    ("window rule wrong effect type", "modules/rules.lua", "float = true,", 'float = "yes",', "expects a boolean"),
    ("unknown window match key", "modules/rules.lua", 'match = { class = ".*" }', 'match = { clas = ".*" }', "unknown match key"),
    ("unknown event", "modules/autostart.lua", 'hl.on("hyprland.start", function()', 'hl.on("hyprland.starts", function()', "unknown event"),
    ("autostart no longer launches the shell", "modules/autostart.lua", 'hl.exec_cmd(S.bin_dir .. "/noctiluca-shell")', "", "noctiluca-shell"),
    ("nonexistent hl function", "modules/monitors.lua", "hl.monitor(S.monitor)", "hl.monitors(S.monitor)", "does not exist in the API"),
    ("Lua syntax error in a module", "modules/gestures.lua", "hl.gesture({", "hl.gesture({{", "Lua error"),
]


def run(workdir: Path):
    cmd = [LUA, str(HARNESS), str(workdir / "hypr"), "--quiet", "--strict"]
    if Path(STUBS).is_file():
        cmd += ["--stubs", STUBS]
    return subprocess.run(cmd, capture_output=True, text=True)


def fresh(tmp: Path) -> Path:
    if tmp.exists():
        shutil.rmtree(tmp)
    (tmp / "hypr").mkdir(parents=True)
    shutil.copytree(CONFIG, tmp / "hypr", dirs_exist_ok=True)
    return tmp


def main() -> int:
    tmp = Path(tempfile.mkdtemp(prefix="hl-mut-"))
    fails = []

    base = run(fresh(tmp))
    print(f"[{'PASS' if base.returncode == 0 else 'FAIL'}] unmodified config passes")
    if base.returncode != 0:
        print(base.stdout)
        fails.append("baseline")

    for name, rel, old, new, expect in MUTATIONS:
        work = fresh(tmp)
        if rel == "design/tokens.json":
            tok = (ROOT / rel).read_text()
            assert old in tok, f"mutation target missing in {rel}: {old!r}"
            alt = work / "tokens.json"
            alt.write_text(tok.replace(old, new))
            subprocess.run([sys.executable, str(ROOT / "scripts" / "gen-tokens"), "--tokens", str(alt),
                            "--hypr-out", str(work / "hypr" / "tokens.lua")], check=True, capture_output=True)
        else:
            f = work / "hypr" / rel
            text = f.read_text()
            assert old in text, f"mutation target missing in {rel}: {old!r}"
            f.write_text(text.replace(old, new, 1))
        r = run(work)
        out = r.stdout + r.stderr
        ok = r.returncode != 0 and expect.lower() in out.lower()
        print(f"[{'PASS' if ok else 'FAIL'}] detects: {name}")
        if not ok:
            fails.append(name)
            print(f"       expected '{expect}', exit={r.returncode}")
            print("       " + "\n       ".join(out.strip().splitlines()[:6]))

    print()
    if fails:
        print(f"RESULT: {len(fails)} blind spot(s): {fails}")
        return 1
    print(f"RESULT: harness detected all {len(MUTATIONS)} injected mistakes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
