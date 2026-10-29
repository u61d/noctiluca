#!/usr/bin/env bash
#   tests/lint.sh [--update]   --update also regenerates docs/KEYBINDS.md
# missing tools are SKIP, never PASS. overrides: LUA, HL_STUBS, FASTFETCH_SCHEMA
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

LUA="${LUA:-$(command -v lua5.5 || command -v lua || true)}"
HL_STUBS="${HL_STUBS:-/usr/share/hypr/stubs/hl.meta.lua}"
UPDATE=0
[ "${1:-}" = "--update" ] && UPDATE=1

pass=0; fail=0; skipped=0
failed_names=()
TMP="$(mktemp -d "${TMPDIR:-/tmp}/noctiluca-lint.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

ok()   { printf '  [PASS] %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  [FAIL] %s\n' "$1"; fail=$((fail + 1)); failed_names+=("$1"); }
skip() { printf '  [SKIP] %s  (%s)\n' "$1" "$2"; skipped=$((skipped + 1)); }

# step "name" cmd...  PASS on exit 0, prints the output on failure
step() {
  local name="$1"; shift
  local out
  if out="$("$@" 2>&1)"; then ok "$name"; else bad "$name"; printf '%s\n' "$out" | sed 's/^/         /' | tail -n 25; fi
}

have() { command -v "$1" >/dev/null 2>&1; }

lua_is_55() { [ -n "$LUA" ] && "$LUA" -v 2>&1 | grep -q 'Lua 5\.5'; }

echo "== tokens and palette"
step "tokens.json: constraints and contrast guarantees" python3 tests/verify_tokens.py
step "generated tokens.lua / Tokens.qml are in sync" \
  python3 scripts/gen-tokens --check --hypr-out config/hypr/tokens.lua --qml-out shell/core/Tokens.qml
if python3 -c 'import PIL' 2>/dev/null; then
  step "palette engine (extraction, guarantees, CLI)" python3 tests/test_palette.py
else
  skip "palette engine tests" "python Pillow not installed (pacman -S python-pillow)"
fi

echo "== theme pipeline"
if python3 -c 'import PIL' 2>/dev/null; then
  step "theme render + validation + reload paths" env LUA="$LUA" python3 tests/test_theme.py
else
  skip "theme pipeline tests" "python Pillow not installed"
fi

echo "== scripts"
step "noctiluca-shell / noctiluca-ctl behaviour" python3 tests/test_scripts.py
step "install.sh: links, backups, idempotence, uninstall" python3 -I tests/test_install.py
if python3 -c 'import PIL' 2>/dev/null; then
  step "noctiluca-wallpaper: listing, setting, refusals, idempotence" python3 -I tests/test_wallpaper.py
else
  skip "noctiluca-wallpaper tests" "python Pillow not installed"
fi
if have shellcheck; then
  step "shellcheck: scripts and this file" shellcheck -s bash scripts/noctiluca-shell scripts/noctiluca-ctl scripts/build-quickshell.sh scripts/build-shaders scripts/install-greeter.sh install.sh tests/lint.sh
else
  skip "shellcheck" "not installed (pacman -S shellcheck)"
fi
# hyprland starts the shell through noctiluca-shell; without the x bit you get an empty desktop
step "every command that gets run is executable" python3 - <<'EOF'
import os, pathlib, sys
cmds = [p for p in pathlib.Path("scripts").iterdir() if p.is_file() and p.read_bytes()[:2] == b"#!"]
cmds += [pathlib.Path("install.sh")]
bad = [str(p) for p in cmds if not os.access(p, os.X_OK)]
if bad:
    sys.exit("not executable (chmod +x): " + " ".join(bad))
print(len(cmds), "commands")
EOF
step "python syntax: scripts and tests" python3 - <<'EOF'
import ast, pathlib, sys
files = [p for p in pathlib.Path("scripts").rglob("*") if p.is_file() and (p.suffix == ".py" or p.name in ("noctiluca-palette", "noctiluca-theme", "noctiluca-wallpaper", "gen-tokens"))]
files += list(pathlib.Path("tests").glob("*.py"))
for f in files:
    ast.parse(f.read_text(), str(f))
print(len(files), "files")
EOF

echo "== Hyprland config (Lua)"
if lua_is_55; then
  # fresh install, no generated colours yet
  rm -rf "$TMP/cfgB" && cp -r config/hypr "$TMP/cfgB"
  stubs=(); [ -f "$HL_STUBS" ] && stubs=(--stubs "$HL_STUBS")
  [ -f "$HL_STUBS" ] || skip "event-name / spec-field checks" "no stubs at $HL_STUBS (installed with Hyprland)"
  step "config executes against the v0.56.2 schema (fresh install, default palette)" \
    "$LUA" tests/hl_harness.lua "$TMP/cfgB" --strict "${stubs[@]}"

  # after noctiluca-theme ran
  rm -rf "$TMP/cfgA" && cp -r config/hypr "$TMP/cfgA"
  XDG_CONFIG_HOME="$TMP/xdgA" XDG_STATE_HOME="$TMP/stateA" HOME="$TMP/homeA" bash -c '
    mkdir -p "$HOME" && python3 scripts/noctiluca-palette --hue 140 >/dev/null && python3 scripts/noctiluca-theme --only hypr --no-reload >/dev/null' \
    && mkdir -p "$TMP/cfgA/generated" && cp "$TMP/xdgA/hypr/generated/colors.lua" "$TMP/cfgA/generated/colors.lua"
  step "config executes against the schema (generated palette, hue 140)" \
    "$LUA" tests/hl_harness.lua "$TMP/cfgA" --strict "${stubs[@]}"

  step "the login screen's Hyprland config executes against the schema" \
    "$LUA" tests/hl_harness.lua greeter --strict --greeter "${stubs[@]}"

  step "mutation tests: harness detects 28 injected mistakes" \
    python3 tests/test_harness.py --lua "$LUA" "${stubs[@]}"

  step "settings app -> Hyprland: every option it writes is one Hyprland knows" \
    python3 tests/test_hypr_bridge.py --lua "$LUA" "${stubs[@]}"

  "$LUA" tests/hl_harness.lua "$TMP/cfgB" --quiet "${stubs[@]}" --keybinds-md "$TMP/KEYBINDS.md" >/dev/null 2>&1
  if [ "$UPDATE" = 1 ]; then
    cp "$TMP/KEYBINDS.md" docs/KEYBINDS.md && ok "docs/KEYBINDS.md regenerated"
  elif [ -f docs/KEYBINDS.md ] && diff -q "$TMP/KEYBINDS.md" docs/KEYBINDS.md >/dev/null; then
    ok "docs/KEYBINDS.md matches the keybinds"
  else
    bad "docs/KEYBINDS.md is out of date (run tests/lint.sh --update)"
  fi
else
  skip "Hyprland config harness, mutation tests, keybind doc" "needs Lua 5.5 (found: ${LUA:-none}); Hyprland 0.56 requires it too"
fi

if have Hyprland; then
  rm -rf "$TMP/real" && cp -r config/hypr "$TMP/real"
  # hyprland aborts without XDG_RUNTIME_DIR (e.g. under su), --verify-config doesn't need a
  # real one
  xrd="${XDG_RUNTIME_DIR:-}"
  if [ -z "$xrd" ] || [ ! -d "$xrd" ]; then
    xrd="$TMP/xdg-runtime"
    mkdir -p "$xrd" && chmod 700 "$xrd"   # only ever chmod a dir we just created ourselves
  fi
  out="$(XDG_RUNTIME_DIR="$xrd" Hyprland --verify-config --config "$TMP/real/hyprland.lua" 2>&1 || true)"
  if printf '%s' "$out" | grep -q 'config ok'; then ok "Hyprland --verify-config: config ok"
  else bad "Hyprland --verify-config"; printf '%s\n' "$out" | sed 's/^/         /' | tail -n 15; fi
else
  skip "Hyprland --verify-config" "Hyprland not installed here; run this on your machine"
fi

echo "== Quickshell shell (QML)"
step "QML: syntax, singletons, imports, properties and enums vs the real Quickshell API" \
  python3 -I tests/check_qml.py
step "mutation tests: the QML checker detects 19 injected mistakes" \
  python3 -I tests/test_qml_checks.py
step "test tooling: attached-statement stripping, stub base mapping" \
  python3 -I tests/test_tools.py
step "settings: reset defaults match, every key the shell reads exists" \
  python3 -I tests/test_settings.py
if python3 -c 'import PySide6' 2>/dev/null; then
  step "launcher: calculator and fuzzy matcher, run through a real QML engine" \
    python3 -I tests/test_search.py
  step "lyrics: title cleanup, lookup order, picking a result, LRC parsing" \
    python3 -I tests/test_lyrics.py
  step "calendar: .ics parsing, repeats, cancelled dates" \
    python3 -I tests/test_calendar.py
else
  skip "launcher logic tests" "PySide6 not installed"
fi
if python3 -c 'import PySide6' 2>/dev/null; then
  step "QML compiles with a real Qt engine (PySide6 + generated Quickshell stubs)" \
    python3 -I tests/load_qml.py
else
  skip "QML load test" "PySide6 not installed (pip install --user pyside6)"
fi

echo "== shell + shader"
QMLLINT="$(command -v qmllint || command -v qmllint6 || true)"
[ -z "$QMLLINT" ] && [ -x /usr/lib/qt6/bin/qmllint ] && QMLLINT=/usr/lib/qt6/bin/qmllint
# no qmllint on shell/: quickshell ships no .qmltypes, so it's all noise. check_qml.py covers it
if [ -n "$QMLLINT" ]; then
  skip "qmllint over shell/" "Quickshell ships no qmltypes; check_qml.py covers this instead"
else
  skip "qmllint" "not installed (qt6-declarative provides it)"
fi
step "shell shaders: bundles, compile, and drawn geometry" python3 -I tests/test_shaders.py
if have glslangValidator; then
  step "screen shader compiles (GLSL ES 3.00)" glslangValidator config/hypr/shaders/vignette-grain.frag
else
  skip "screen shader compile check" "glslangValidator not installed (pacman -S glslang)"
fi

echo
printf 'SUMMARY: %d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skipped"
if [ "$fail" -gt 0 ]; then printf 'FAILED: %s\n' "${failed_names[*]}"; exit 1; fi
exit 0
