#!/usr/bin/env python3
"""palette -> noctiluca-theme -> every target, each checked with the best tool on the machine.

    LUA=/path/to/lua5.5 FASTFETCH_SCHEMA=/path/to/json_schema.json python3 tests/test_theme.py
"""
import configparser
import importlib.machinery
import importlib.util
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts" / "lib"))
import noctiluca_color as nc  # noqa: E402

PALETTE = ROOT / "scripts" / "noctiluca-palette"
THEME = ROOT / "scripts" / "noctiluca-theme"
fails, skips = [], []


def check(ok, label, detail=""):
    print(f"  [{'PASS' if ok else 'FAIL'}] {label}" + (f"  ({detail})" if detail else ""))
    if not ok:
        fails.append(label)


def skip(label, why):
    print(f"  [SKIP] {label}  ({why})")
    skips.append(label)


def sh(*cmd, env=None, **kw):
    return subprocess.run([str(c) for c in cmd], capture_output=True, text=True, env=env, **kw)


tmp = Path(tempfile.mkdtemp(prefix="noct-theme-"))
env = {**os.environ, "HOME": str(tmp / "home"), "XDG_CONFIG_HOME": str(tmp / "config"), "XDG_STATE_HOME": str(tmp / "state"),
       "PYTHONDONTWRITEBYTECODE": "1"}
(tmp / "home").mkdir()
CFG = tmp / "config"
tokens = nc.load_tokens()

LUA = os.environ.get("LUA") or shutil.which("lua5.5") or shutil.which("lua")

print("render")
r = sh(sys.executable, PALETTE, "--hue", "195", env=env)
check(r.returncode == 0, "palette generated", r.stdout.strip())
(CFG).mkdir(parents=True, exist_ok=True)
(CFG / "kdeglobals").write_text("[General]\nfont=Foo,10\nColorScheme=BreezeLight\n\n[Colors:View]\nBackgroundNormal=255,255,255\n\n[KDE]\nSingleClick=false\n")
r = sh(sys.executable, THEME, "--setup", "--no-reload", env=env)
check(r.returncode == 0 and r.stdout.count("written") == 14, "all 14 targets written (9 palette + 5 static)", f"exit {r.returncode}")
r2 = sh(sys.executable, THEME, "--setup", "--no-reload", env=env)
check(r2.returncode == 0 and "written" not in r2.stdout.replace("unchanged", ""), "second run is idempotent (all unchanged)")
r3 = sh(sys.executable, THEME, "--no-reload", env=env)
check("qt6ct.conf" not in r3.stdout and "settings.ini" not in r3.stdout, "static targets are NOT rewritten without --setup")

pal = json.loads((tmp / "state" / "noctiluca" / "palette.json").read_text())
roles = pal["roles"]
check(not [f for f in CFG.rglob("*") if f.is_file() and "{{" in f.read_text()], "no unresolved {{placeholders}} in any output")

print("hyprland colours")
if LUA:
    code = f'local c=dofile("{CFG}/hypr/generated/colors.lua"); assert(c.glow=="{roles["glow"][1:]}" and c.void=="{roles["void"][1:]}"); print("ok")'
    r = sh(LUA, "-e", code)
    check(r.returncode == 0 and "ok" in r.stdout, "colors.lua loads in Lua and matches the palette", r.stderr.strip()[:100])
else:
    skip("colors.lua loads in Lua", "no lua found (set LUA=)")

print("kitty")
shutil.copy(ROOT / "config" / "kitty" / "kitty.conf", CFG / "kitty" / "kitty.conf")
loader_ok = False
for libdir in ("/usr/lib/kitty", "/usr/lib64/kitty", "/opt/kitty/lib/kitty"):
    if (Path(libdir) / "kitty" / "config.py").is_file():
        code = (
            "import sys; sys.path.insert(0, %r)\n"
            "from kitty.config import load_config\n"
            "bad=[]\n"
            "o=load_config(%r, accumulate_bad_lines=bad)\n"
            "print('BAD', bad); print('FG', o.foreground.red, o.foreground.green, o.foreground.blue); print('CUR', o.cursor.red, o.cursor.green, o.cursor.blue)\n"
            "print('C1', o.color1.red, o.color1.green, o.color1.blue)\n"
            "fam = o.font_family\n"
            "for a in ('family', 'created_from_string', 'postscript_name', 'full_name'):\n"
            "    v = getattr(fam, a, None)\n"
            "    if isinstance(v, str) and v:\n"
            "        fam = v; break\n"
            "else:\n"
            "    fam = str(fam)\n"
            "print('FONT', fam)\n"
        ) % (libdir, str(CFG / "kitty" / "kitty.conf"))
        r = sh(sys.executable, "-c", code)
        if r.returncode == 0:
            loader_ok = True
            out = r.stdout
            check("BAD []" in out, "kitty's own loader: kitty.conf + colors parse with zero bad lines", out.splitlines()[0] if out else "")
            fg = nc.hex_to_rgb8(roles["text"])
            check(f"FG {fg[0]} {fg[1]} {fg[2]}" in out, "kitty reads foreground = text role")
            cur = nc.hex_to_rgb8(roles["glow"])
            check(f"CUR {cur[0]} {cur[1]} {cur[2]}" in out, "kitty reads cursor = glow role")
            red = nc.hex_to_rgb8(roles["ansi_red"])
            check(f"C1 {red[0]} {red[1]} {red[2]}" in out, "kitty reads color1 = ansi_red")
            # font_family is a str in older kitty and an object in 0.33+
            fontline = next((l for l in out.splitlines() if l.startswith("FONT ")), "")
            check("IBM Plex Mono" in fontline, "kitty reads font_family", fontline[:110])
        else:
            skip("kitty loader", r.stderr.strip().splitlines()[-1][:100] if r.stderr else "failed")
        break
if not loader_ok and "kitty loader" not in skips:
    skip("kitty's own config loader", "kitty python package not found")

print("GTK")
for ver in ("gtk-3.0", "gtk-4.0"):
    css = (CFG / ver / "noctiluca-colors.css").read_text()
    defs = dict(re.findall(r"@define-color\s+([a-z_]+)\s+([^;]+);", css))
    need = ["window_bg_color", "window_fg_color", "view_bg_color", "accent_bg_color", "accent_fg_color", "accent_color",
            "headerbar_bg_color", "card_bg_color", "popover_bg_color", "destructive_bg_color", "sidebar_bg_color"]
    check(all(n in defs for n in need), f"{ver}: libadwaita named colours present", f"{len(defs)} defined")
    bad = [v for v in defs.values() if not re.fullmatch(r"#[0-9a-f]{6}|rgba\(\d+, \d+, \d+, [0-9.]+\)", v.strip())]
    check(not bad, f"{ver}: every value is #rrggbb or rgba()", str(bad[:2]))
    check(defs["window_bg_color"].strip() == roles["ink"], f"{ver}: window_bg_color = ink role")
    gtkcss = (CFG / ver / "gtk.css").read_text()
    check('@import url("noctiluca-colors.css");' in gtkcss, f"{ver}: gtk.css imports the generated colours")
    cp = configparser.ConfigParser(interpolation=None)
    cp.read(CFG / ver / "settings.ini")
    check(cp["Settings"]["gtk-theme-name"] == "adw-gtk3-dark" and "IBM Plex Sans" in cp["Settings"]["gtk-font-name"], f"{ver}: settings.ini theme + font")

print("Qt (qt6ct)")
txt = (CFG / "qt6ct" / "colors" / "noctiluca.conf").read_text()
for key in ("active_colors", "disabled_colors", "inactive_colors"):
    cols = [c.strip() for c in re.search(rf"^{key}=(.*)$", txt, re.M).group(1).split(",")]
    check(len(cols) == 21 and all(re.fullmatch(r"#[0-9a-f]{8}", c) for c in cols), f"{key}: 21 x #aarrggbb (qt6ct format)")
active = [c.strip() for c in re.search(r"^active_colors=(.*)$", txt, re.M).group(1).split(",")]
check(active[0] == "#ff" + roles["text"][1:] and active[10] == "#ff" + roles["ink"][1:] and active[12] == "#ff" + roles["glow_lo"][1:],
      "QPalette order: WindowText=text, Window=ink, Highlight=glow_lo")
cp = configparser.ConfigParser(interpolation=None)
cp.read(CFG / "qt6ct" / "qt6ct.conf")
check(cp["Appearance"]["color_scheme_path"] == str(CFG / "qt6ct" / "colors" / "noctiluca.conf") and cp["Appearance"]["style"] == "Fusion"
      and cp["Appearance"]["custom_palette"] == "true", "qt6ct.conf points at the generated scheme (absolute path), Fusion style")

print("KDE apps (kdeglobals)")
kde = configparser.ConfigParser(interpolation=None, strict=False)
kde.optionxform = str
kde.read(CFG / "kdeglobals")
ink = ",".join(str(c) for c in nc.hex_to_rgb8(roles["ink"]))
void = ",".join(str(c) for c in nc.hex_to_rgb8(roles["void"]))
check(kde["Colors:Window"]["BackgroundNormal"] == ink and kde["Colors:View"]["BackgroundNormal"] == void,
      "dark window and view backgrounds (so dolphin isn't white)")
check(kde["General"]["ColorScheme"] == "Noctiluca" and kde["General"]["font"] == "Foo,10" and kde["KDE"]["SingleClick"] == "false",
      "what was already in kdeglobals is kept, only the colours change")
check((tmp / "home" / ".local" / "share" / "color-schemes" / "Noctiluca.colors").is_file(), "the scheme file exists for kde's own settings")
r = sh(sys.executable, THEME, "--only", "kde", "--no-reload", env=env)
check("unchanged" in r.stdout, "running it again doesn't change kdeglobals", r.stdout.strip())

print("fastfetch")
schema_path = os.environ.get("FASTFETCH_SCHEMA")
raw = re.sub(r"^\s*//.*$", "", (CFG / "fastfetch" / "config.jsonc").read_text(), flags=re.M)
doc = json.loads(raw)
glow_sgr = "38;2;{};{};{}".format(*nc.hex_to_rgb8(roles["glow"]))
keyed = [m for m in doc["modules"] if isinstance(m, dict) and "key" in m]
check(keyed and all(glow_sgr in m["key"] for m in keyed), "every key's icon is in the accent (24-bit SGR)")
logo = doc["logo"]
check(logo["type"] == "data" and ".-----." in logo["source"] and len(logo["source"].splitlines()) <= 10,
      "the logo is the small ascii one")
check(logo["color"]["1"] == glow_sgr, "the logo is drawn in the accent", logo["color"]["1"])
if schema_path and Path(schema_path).is_file():
    try:
        import jsonschema
        schema = json.loads(Path(schema_path).read_text())
        V = jsonschema.validators.validator_for(schema)(schema)
        errs = list(V.iter_errors(doc))
        check(not errs, "config validates against fastfetch's official JSON schema", f"{len(errs)} errors")
        bad = json.loads(raw)
        bad["modules"].append({"type": "definitely-not-a-module"})
        check(len(list(V.iter_errors(bad))) > 0, "negative control: a broken config does NOT validate")
    except ImportError:
        skip("fastfetch schema validation", "python jsonschema not installed")
else:
    skip("fastfetch schema validation", "set FASTFETCH_SCHEMA to the official json_schema.json")

print("zsh prompt")
zsh = shutil.which("zsh")
if zsh:
    (CFG / "zsh").mkdir(exist_ok=True)
    prompt = ROOT / "config" / "zsh" / "noctiluca.zsh"
    nd = CFG / "noctiluca"
    nd.mkdir(exist_ok=True)
    shutil.copy(prompt, nd / "prompt.zsh")
    # the prompt is built in precmd, so call it
    script = 'source "$XDG_CONFIG_HOME/noctiluca/prompt.zsh"; %s; _noct_precmd >/dev/null; print -P -- "$PROMPT"'
    zenv = {**env, "TERM": "xterm-256color"}

    def prompt_after(cmd, cwd=None, e=zenv):
        return sh(zsh, "-f", "-i", "-c", script % cmd, env=e, cwd=cwd)

    ok = prompt_after("true")
    ko = prompt_after("(exit 3)")
    glow = "38;2;{};{};{}".format(*nc.hex_to_rgb8(roles["glow"]))
    sig = "38;2;{};{};{}".format(*nc.hex_to_rgb8(roles["signal"]))
    arrow_ok = ok.stdout.rstrip("\n").rsplit("\n", 1)[-1]
    arrow_ko = ko.stdout.rstrip("\n").rsplit("\n", 1)[-1]
    check(ok.returncode == 0 and "❯" in arrow_ok and glow in arrow_ok, "success: the arrow is in the accent (truecolor)", ok.stderr.strip()[:120])
    check(ko.returncode == 0 and sig in arrow_ko and "exit 3" in ko.stdout, "failure: the arrow turns `signal` and the code is shown")
    check("exit" not in ok.stdout, "no exit code after a command that worked")
    slow = prompt_after("_noct_started=$(( EPOCHREALTIME - 3.2 ))")
    check("took 3.2s" in slow.stdout, "a slow command shows how long it took", slow.stdout.strip()[-60:])
    quick = prompt_after("_noct_started=$(( EPOCHREALTIME - 0.4 ))")
    check("took" not in quick.stdout, "a quick one doesn't")
    repo = tmp / "repo" / "deep" / "leafdir"
    repo.mkdir(parents=True)
    if shutil.which("git"):
        sh("git", "init", "-q", "-b", "trunk", str(tmp / "repo"))
        (tmp / "repo" / "f").write_text("x")
        sh("git", "-C", str(tmp / "repo"), "add", "f")
        g = prompt_after("true", cwd=repo)
        check("trunk" in g.stdout and "+" in g.stdout, "in a repo: the branch, and + for staged changes", g.stdout.strip()[:120])
        check("leafdir" in g.stdout and "\x1b[1m" in g.stdout, "the folder you're in is bold, the path to it quiet")
    else:
        skip("git in the prompt", "git not installed")
    short = sh(zsh, "-f", "-i", "-c", 'source "$XDG_CONFIG_HOME/noctiluca/prompt.zsh"; _noct_precmd >/dev/null; print -P -- "$_noct_short"', env=zenv)
    check(short.stdout.strip().endswith("❯") or "❯" in short.stdout, "the shrunk prompt is just the arrow")
    env2 = {**zenv, "XDG_CONFIG_HOME": str(tmp / "empty")}
    nopal = sh(zsh, "-f", "-i", "-c", 'source "%s"; _noct_precmd >/dev/null; print -P -- "$PROMPT"' % (nd / "prompt.zsh"), env=env2)
    check(nopal.returncode == 0 and "❯" in nopal.stdout and "38;2;127;221;221" in nopal.stdout,
          "works without a palette file (falls back to the reference colours)", nopal.stderr.strip()[:120])
    plain = sh(zsh, "-f", "-c", 'source "%s"; print -r -- "${PROMPT:-unset}"' % (nd / "prompt.zsh"), env=zenv)
    check(plain.returncode == 0 and plain.stdout.strip() != "" and "❯" not in plain.stdout,
          "a non-interactive zsh (a script) is left alone")
    fhome = tmp / "fetchhome"
    (fhome / "bin").mkdir(parents=True)
    (fhome / "bin" / "fastfetch").write_text("#!/bin/sh\necho FETCHED\n")
    (fhome / "bin" / "fastfetch").chmod(0o755)
    fenv = {**zenv, "HOME": str(fhome), "TERM": "xterm-kitty", "PATH": f"{fhome / 'bin'}:/usr/bin:/bin", "ZDOTDIR": str(fhome)}
    fenv.pop("SHLVL", None)
    src = f'source "{nd / "prompt.zsh"}"'
    for label, rc, want in [("sourced twice", f"{src}\n{src}\n", 1),
                            ("a fastfetch of your own in .zshrc", f"fastfetch\n{src}\n", 1),
                            ("a commented-out one doesn't count", f"# fastfetch\n{src}\n", 1),
                            ("NOCTILUCA_FASTFETCH=0", f"NOCTILUCA_FASTFETCH=0\n{src}\n", 0)]:
        (fhome / ".zshrc").write_text(rc)
        out = sh(zsh, "-i", "-c", "true", env=fenv)
        check(out.stdout.count("FETCHED") == want, f"fastfetch {want}x: {label}", f"got {out.stdout.count('FETCHED')}")
    colors = (CFG / "noctiluca" / "colors.zsh").read_text()
    check("EZA_COLORS=" in colors and "LS_COLORS=" in colors and f"di=1;{glow}" in colors, "ls and eza colours come from the palette")
else:
    skip("zsh prompt", "zsh not installed")

print("live reload paths (fake hyprctl / pkill)")
spec = importlib.util.spec_from_loader("noctiluca_theme", importlib.machinery.SourceFileLoader("noctiluca_theme", str(THEME)))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

fake = tmp / "fakebin"
fake.mkdir()
log = tmp / "calls.log"


def exe(name, body):
    p = fake / name
    p.write_text("#!/bin/sh\n" + body)
    p.chmod(p.stat().st_mode | stat.S_IEXEC)


old_path, old_env = os.environ["PATH"], dict(os.environ)
os.environ["PATH"] = f"{fake}:/usr/bin:/bin"
os.environ["LOG"] = str(log)
try:
    exe("pkill", 'echo "pkill $*" >> "$LOG"\nexit 0\n')
    msg = mod.reload_kitty()
    calls = log.read_text()
    check(f"-U {os.getuid()}" in calls and "-x" in calls and calls.strip().endswith("kitty") and "SIGUSR1" in msg,
          "kitty reload signals only OUR OWN kitty (-U uid)", calls.strip())

    # another user's kitty on a second vt can't be signalled; without -U pkill printed EPERM
    # and still said it worked
    log.write_text("")
    exe("pkill", 'echo "pkill $*" >> "$LOG"\necho "pkill: killing pid 6917 failed: Operation not permitted" >&2\nexit 1\n')
    msg = mod.reload_kitty()
    check("Operation not permitted" in msg, "a pkill warning is surfaced verbatim, not hidden behind success", msg)

    log.write_text("")
    exe("pkill", 'exit 1\n')
    msg = mod.reload_kitty()
    check("no kitty" in msg, "no kitty running -> says so plainly", msg)

    os.environ.pop("HYPRLAND_INSTANCE_SIGNATURE", None)
    check("not running" in mod.reload_hypr(), "Hyprland not running -> no hyprctl call, clear message")

    os.environ["HYPRLAND_INSTANCE_SIGNATURE"] = "test"
    log.write_text("")
    exe("hyprctl", 'echo "hyprctl $*" >> "$LOG"\necho ok\nexit 0\n')
    msg = mod.reload_hypr()
    calls = log.read_text()
    check("applied live" in msg and 'require("modules.theme").apply()' in calls and "hyprctl reload" not in calls,
          "eval path: `hyprctl eval` runs modules.theme.apply(), no full reload")
    log.write_text("")
    exe("hyprctl", 'echo "hyprctl $*" >> "$LOG"\n[ "$1" = "eval" ] && echo "error: attempt to index a nil value"\nexit 0\n')
    msg = mod.reload_hypr()
    check("fell back to hyprctl reload" in msg and "hyprctl reload" in log.read_text(), "eval error -> falls back to `hyprctl reload` and says so")
finally:
    os.environ.clear()
    os.environ.update(old_env)

print("generated artifacts are in sync with their sources")
r = sh(sys.executable, ROOT / "scripts" / "gen-tokens", "--check", "--hypr-out", ROOT / "config/hypr/tokens.lua", "--qml-out", ROOT / "shell/core/Tokens.qml")
check(r.returncode == 0, "tokens.lua and Tokens.qml match tokens.json", r.stderr.strip())
ref_state = tmp / "ref-state"
ref_cfg = tmp / "ref-cfg"
e3 = {**env, "XDG_STATE_HOME": str(ref_state), "XDG_CONFIG_HOME": str(ref_cfg)}
sh(sys.executable, PALETTE, "--reference", env=e3)
sh(sys.executable, THEME, "--only", "hypr", "--no-reload", env=e3)
check((ref_cfg / "hypr/generated/colors.lua").read_text() == (ROOT / "config/hypr/palette_default.lua").read_text(),
      "palette_default.lua equals the template rendered for the reference hue")

print()
if fails:
    print(f"RESULT: {len(fails)} FAILED: {fails}")
    sys.exit(1)
print(f"RESULT: all theme tests passed ({len(skips)} skipped: {', '.join(skips) if skips else 'none'})")
