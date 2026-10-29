#!/usr/bin/env python3
"""renders panels of the real Surface through the gpu path with fixture data.

    python3 tests/render_scenes.py OUTDIR [scene ...]

scenes: closed control dashboard player launcher power picker overview toasts arrival ...
"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEMPLATE = ROOT / "design" / "previews" / "surface.qml"

# long timeouts, software rendering is slower than a toast lives
TOASTS = '''Notifs.popups = [
    { appName: "firefox", summary: "Download finished", body: "arch-2026.10.01-x86_64.iso — 1.2 GB",
      urgency: 1, expireTimeout: 600000, actions: [ { text: "Open", invoke: function() {} },
                                                { text: "Show in folder", invoke: function() {} } ],
      image: "", time: new Date() },
    { appName: "spotify", summary: "Halocline", body: "Marrow &amp; Salt — Low Tide",
      urgency: 1, expireTimeout: 600000, actions: [], image: Qt.resolvedUrl("stubs/art.png").toString(), time: new Date() },
    { appName: "colour picker", summary: "#3a8fb7 copied", body: "rgb(58, 143, 183)  ·  hsl(199, 52%, 47%)", swatch: "#3a8fb7",
      urgency: 0, expireTimeout: 600000, actions: [], image: "", time: new Date() }
];'''

ARRIVAL = '''Notifs.receive({ id: 7, appName: "notify-send", appIcon: "", summary: "Hello from notify-send",
    body: "It came in through <b>Notifs.receive</b>, like any other", image: "", urgency: 1,
    expireTimeout: 600000, actions: [] });'''

HISTORY = '''Notifs.history = [
    { appName: "firefox", summary: "Download finished", body: "arch-2026.10.01-x86_64.iso", time: new Date(Date.now() - 120000), seen: true },
    { appName: "discord", summary: "Jonas", body: "bro the rice looks insane now", time: new Date(Date.now() - 540000), seen: true },
    { appName: "systemd", summary: "Backup complete", body: "home → nas: 3.2 GB in 4 min", time: new Date(Date.now() - 7200000), seen: true }
];'''

SCENES = {
    "closed": ("", ""),
    # a terminal running something with a very long title, next to the music
    "long-title": ("", "Hyprland.activeToplevel = { title: 'notify-send \"Download finished\" \"noctiluca-1.0.0-beta.4.tar.gz\"; notify-send -i spotify \"Spotify\" \"Now playing\"; sleep 5; grim control.png', wayland: { appId: 'kitty' } };"),
    "closed-numbers": ("", 'Settings.bar.workspaceStyle = "numbers";'),
    "closed-motes": ("", 'Settings.bar.workspaceStyle = "motes";'),
    "control": ("control", HISTORY + " NightLight.available = true; Recorder.tool = 'gsr'; Settings.nightLight.enabled = true;"),
    "dashboard": ("dashboard", "SystemStats.cpu = 0.34; SystemStats.memTotal = 34359738368; SystemStats.memUsed = 13958643712; "
                               "SystemStats.hasGpu = true; SystemStats.gpu = 0.18; SystemStats.gpuTemp = 47; SystemStats.gpuName = 'GeForce GTX 1080'; "
                               "SystemStats.gpuPower = 41; SystemStats.cpuTemp = 52; SystemStats.diskTotal = 1000204886016; SystemStats.diskUsed = 412316860416; "
                               "const wave = function(n, base, amp, f, ph) { const o = []; for (let i = 0; i < n; i++) o.push(Math.max(0, base + amp * Math.sin(i * f + ph) + amp * 0.6 * Math.sin(i * f * 2.7 + ph * 3))); return o; }; "
                               "SystemStats.cpuHistory = wave(60, 0.28, 0.16, 0.21, 0.4); SystemStats.memHistory = wave(60, 0.40, 0.012, 0.05, 1); "
                               "SystemStats.gpuHistory = wave(60, 0.14, 0.10, 0.33, 2); SystemStats.cores = 16; "
                               "SystemStats.rxHistory = wave(60, 900000, 700000, 0.4, 0.2); SystemStats.txHistory = wave(60, 120000, 90000, 0.5, 1.3); "
                               "SystemStats.rxRate = 1340000; SystemStats.txRate = 84000; SystemStats.kernel = '6.17.4-arch1-1'; "
                               "Weather.hours = (function() { const o = []; for (let i = 0; i < 25; i++) { const h = (2 + i) % 24; "
                               "  o.push({ time: '2026-10-24T' + (h < 10 ? '0' : '') + h + ':00', temp: 15.5 + 5.5 * Math.sin((h - 9) / 24 * 2 * Math.PI), "
                               "           code: 2, rain: i > 14 && i < 21 ? 40 + i : 5, isDay: h > 7 && h < 19 }); } return o; })(); "
                               "Settings.calendar.sources = ['~/calendar.ics']; "
                               "const d0 = new Date(); const at = function(dd, h, m) { return new Date(d0.getFullYear(), d0.getMonth(), d0.getDate() + dd, h, m); }; "
                               "Calendar.events = [ { start: at(0, 18, 30), end: at(0, 19, 30), allDay: false, title: 'Climbing with Jonas', location: 'Boulderhalle', source: 0 }, "
                               "  { start: at(1, 9, 0), end: at(1, 9, 15), allDay: false, title: 'Standup', location: '', source: 1 }, "
                               "  { start: at(3, 0, 0), end: at(4, 0, 0), allDay: true, title: 'Mum’s birthday', location: '', source: 0 } ]; "
                               "Calendar.marked = Calendar.events.map(function(e) { return Calendar.key(e.start); }).concat([Calendar.key(at(8, 9, 0)), Calendar.key(at(12, 9, 0))]); "
                               "Weather.place = 'Lisbon, Portugal'; "
                               "Weather.current = { temp: 18.4, feels: 17.1, code: 2, isDay: false, wind: 14, humidity: 72 }; "
                               "Weather.days = [ {date:'2026-10-23',max:21,min:14,code:2}, {date:'2026-10-24',max:22,min:15,code:1}, "
                               "{date:'2026-10-25',max:19,min:13,code:61}, {date:'2026-10-26',max:17,min:12,code:63}, {date:'2026-10-27',max:20,min:13,code:3} ];"),
    # lyrics and spectrum go in after the panel opens (opening clears them)
    "player": ("player", "", "Lyrics.lines = [ { t: 80, text: 'Salt on the window, the tide coming in' }, "
                             "{ t: 88, text: 'Every light on the water is something that moved' }, "
                             "{ t: 97, text: 'Hold still and it fades, so I never hold still' }, "
                             "{ t: 104, text: 'Down where the cold keeps the colours' } ]; Lyrics.state = 'ok'; "
                             "const lv = []; for (let i = 0; i < Cava.bars; i++) lv.push(Math.max(0.05, 0.85 * Math.exp(-i / 14) + 0.25 * Math.abs(Math.sin(i * 0.9)))); Cava.levels = lv;"),
    "player-nolyrics": ("player", ""),
    "player-long": ("player", "Players.active.trackTitle = 'Everything You Left in the Glovebox of the Old Car (Extended Night Version, Remastered 2024)'; "
                              "Players.active.trackArtists = 'The Unbearable Lightness of Being Asleep, Featuring a Very Long Name'; "
                              "Players.active.trackAlbum = 'Songs Recorded in a Lighthouse Between Two Winters, Deluxe Edition';"),
    "launcher": ("launcher", ""),
    # the stubbed FileView reads nothing
    "launcher-emoji": ("launcher", "Emoji.all = " + json.dumps(json.loads((ROOT / "shell/data/emoji.json").read_text())["emoji"], ensure_ascii=False)
                                   + "; Emoji.recent = ['🌊', '🐙', '✨']; Panels.launcherMode = 'emoji';"),
    "launcher-colors": ("launcher", "Panels.launcherMode = 'colors'; Picker.recent = ['#3a8fb7', '#e2725b', '#f2c14e', '#6c5ce7'];"),
    "power": ("power", ""),
    "picker": ("picker", "const dir = Qt.resolvedUrl('walls/').toString().replace('file://', ''); "
                         "Wallpapers.scanning = false; "
                         "Wallpapers.list = ['ember_shoal', 'fen', 'slate_rain', 'salt_flat', 'kelp'].map(function(n, i) { "
                         "  return { path: dir + n + '.png', name: n.replace('_', ' '), current: i === 1 }; }); "
                         "Wallpapers.previewHue = 32;"),
    # after the pool stops ignoring startup values
    "osd": ("", "", "", "Pipewire.defaultAudioSink.audio.volume = n % 2 ? 0.64 : 0.65;"),
    "osd-layout": ("", "Keyboard.layouts = ['us', 'de', 'ua']; Keyboard.keymap = 'German';", "", "Keyboard.index = n % 2;"),
    "overview": ("overview", "Wallpapers._current = Qt.resolvedUrl('sea.png').toString().replace('file://', '');"),
    "toasts": ("", TOASTS),
    "arrival": ("", ARRIVAL),
    "mixer": ("mixer", ""),
    "record": ("record", "Recorder.tool = 'gsr';"),
    "tray": ("tray", "Panels.trayItem = SystemTray.items.values[0];"),
    "network": ("network", ""),
    "bluetooth": ("bluetooth", ""),
    "capture": ("capture", ""),
}

SETTINGS = ["look", "motion", "bar", "notifications", "desktop", "nightlight", "panels", "lock", "windows", "input", "about"]


def main() -> int:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    out = Path(sys.argv[1]).resolve()
    out.mkdir(parents=True, exist_ok=True)
    wanted = sys.argv[2:] or list(SCENES) + ["settings-" + s for s in SETTINGS] + ["polkit", "capture-overlay", "greeter"]
    work = Path(tempfile.mkdtemp(prefix="noct-scenes-"))
    failed = []
    for name in wanted:
        if name == "greeter":
            src = (ROOT / "design" / "previews" / "greeter.qml").read_text()
        elif name in ("polkit", "capture-overlay"):
            which = "polkit" if name == "polkit" else "capture"
            src = (ROOT / "design" / "previews" / "prompts.qml").read_text().replace("@WHICH@", which)
        elif name.startswith("settings-"):
            src = (ROOT / "design" / "previews" / "settings.qml").read_text().replace("@PAGE@", name[9:])
        else:
            panel, setup, *later = SCENES[name]
            src = (TEMPLATE.read_text().replace("@PANEL@", panel).replace("@SETUP@", setup)
                   .replace("@LATER@", later[0] if later else "")
                   .replace("@EVERY@", later[1] if len(later) > 1 else ""))
        scene = work / name / f"{name}.qml"
        scene.parent.mkdir(parents=True, exist_ok=True)
        scene.write_text(src)
        r = subprocess.run([sys.executable, str(ROOT / "tests" / "render_qml.py"), str(scene),
                            str(out / f"{name}.png"), "--gpu", "--scene", "--wait=9000"],
                           capture_output=True, text=True, timeout=400)
        msgs = [l for l in (r.stdout + r.stderr).splitlines()
                if l.strip() and "locale" not in l.lower() and "utf-8" not in l.lower()
                and "reconfigure" not in l and "more information" not in l]
        ok = r.returncode == 0 and (out / f"{name}.png").exists()
        print(f"  [{'OK  ' if ok else 'FAIL'}] {name}")
        for m in msgs:
            if not m.startswith("rendered"):
                print(f"         {m}")
        if not ok:
            failed.append(name)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
