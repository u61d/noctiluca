pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// ~/.config/noctiluca/settings.json. missing keys keep the defaults below so old files
// still load
Singleton {
    id: root

    readonly property string path: Paths.configDir + "/noctiluca/settings.json"

    readonly property string timeFormat: adapter.appearance.clock24h ? "HH:mm" : "h:mm AP"
    readonly property string barTimeFormat: adapter.appearance.clock24h
        ? (adapter.appearance.clockSeconds ? "HH:mm:ss" : "HH:mm")
        : (adapter.appearance.clockSeconds ? "h:mm:ss AP" : "h:mm AP")

    property alias appearance: adapter.appearance
    property alias motion: adapter.motion
    property alias bar: adapter.bar
    property alias notifications: adapter.notifications
    property alias desktop: adapter.desktop
    property alias wallpaper: adapter.wallpaper
    property alias dashboard: adapter.dashboard
    property alias player: adapter.player
    property alias overview: adapter.overview
    property alias lock: adapter.lock
    property alias idle: adapter.idle
    property alias hypr: adapter.hypr
    property alias nightLight: adapter.nightLight
    property alias recorder: adapter.recorder
    property alias launcher: adapter.launcher
    property alias calendar: adapter.calendar

    // don't write on every slider tick
    Timer {
        id: save
        interval: 400
        onTriggered: file.writeAdapter()
    }

    FileView {
        id: file
        path: root.path
        watchChanges: true
        printErrors: false
        onFileChanged: this.reload()
        onAdapterUpdated: save.restart()
        // first run, write the defaults out
        onLoadFailed: function(error) {
            if (error === FileViewError.FileNotFound)
                save.restart();
        }

        JsonAdapter {
            id: adapter

            property JsonObject appearance: JsonObject {
                property string accent: "wallpaper"      // "wallpaper" or "fixed"
                property real hue: 186                    // used when accent is "fixed"
                property real inkOpacity: 0.97
                property real light: 1.0                  // how bright the rim and the bloom are
                property bool clock24h: true
                property bool clockSeconds: false
                property bool musicInk: true              // the rim of the ink moves with the music
                property real musicInkGain: 1.0
            }

            property JsonObject motion: JsonObject {
                property real speed: 1.0                  // 0.5 slow .. 2 snappy
                property real bounce: 0.5                 // 0 none .. 1 a lot
                property real stretch: 1.0                // how much moving ink deforms
                property bool reduce: false               // fades instead of movement
            }

            property JsonObject bar: JsonObject {
                property int workspaces: 5                // always shown, more appear when used
                property string workspaceStyle: "lens"    // lens, numbers, motes
                property bool tintIcons: true             // the lens's app icons in the accent
                property bool windowTitle: true
                property bool nowPlaying: true
                property bool touchLight: true            // clicks send light through the ink
                property bool tray: true
                property bool hideOnFullscreen: true      // the ink leaves a fullscreen window alone
                property bool battery: true               // only shows on machines with one
                property bool layout: true                // only shows with two layouts or more
            }

            property JsonObject notifications: JsonObject {
                property bool dnd: false
                property int timeout: 6                   // seconds
                property int maxToasts: 4
                property bool groupByApp: true
                property bool images: true                // pictures that come with notifications
            }

            property JsonObject desktop: JsonObject {
                property bool clock: true
                property string clockCorner: "left"       // "left" or "right"
                property bool plankton: true
                property real planktonGain: 1.0
            }

            property JsonObject wallpaper: JsonObject {
                property string transition: "tide"        // "tide" or "fade"
                property real tideSeconds: 1.5
            }

            property JsonObject dashboard: JsonObject {
                property string weatherCity: ""
                property bool fahrenheit: false
                property bool gpu: true
            }

            property JsonObject player: JsonObject {
                property bool trackHue: true
                property bool visualizer: true
                property int bars: 48
                property bool lyrics: true
            }

            property JsonObject overview: JsonObject {
                property bool live: true
            }

            property JsonObject lock: JsonObject {
                property bool blur: true
                property bool media: true
                property bool notifications: true
                property bool weather: true
            }

            property JsonObject idle: JsonObject {
                property int lockMinutes: 5               // 0 = never
                property int screenOffMinutes: 6          // 0 = never
                property int suspendMinutes: 0            // 0 = never
                property bool caffeine: false             // keep the screen awake
                property bool awakeForMusic: true         // no lock or screen off while something plays
            }

            // applied live with hyprctl eval and saved to a lua file (services/HyprSettings.qml)
            property JsonObject hypr: JsonObject {
                property int gapsIn: 4
                property int gapsOut: 8
                property int border: 1
                property int rounding: 12
                property bool dimInactive: true
                property real dimStrength: 0.10
                property bool shadow: true
                property bool glow: true
                property bool blur: true
                property bool animations: true
                property real animationSpeed: 1.0
                property string kbLayout: ""              // empty = whatever local.lua says
                property string kbVariant: ""
                property string kbOptions: ""
                property int repeatRate: 35
                property int repeatDelay: 250
                property real sensitivity: 0
                property string accelProfile: "flat"
                property bool naturalScroll: true         // touchpads only
                property bool tapToClick: true
                property int followMouse: 1
            }

            property JsonObject nightLight: JsonObject {
                property bool enabled: false
                property int temperature: 4000            // kelvin
                property bool scheduled: false
                property string from: "21:00"
                property string to: "07:00"
            }

            property JsonObject recorder: JsonObject {
                property string folder: ""                // empty = ~/Videos/Recordings
                property int fps: 60
                property bool systemAudio: true
                property bool microphone: false
                property bool cursor: true
            }

            property JsonObject launcher: JsonObject {
                property bool files: true                 // search your home folder too
                property bool windows: true
                property bool settings: true
            }

            property JsonObject calendar: JsonObject {
                property var sources: []
                property int days: 14                     // how far ahead to list
            }
        }
    }

    function reset(group: string): void {
        const defaults = root.defaults[group];
        if (!defaults) return;
        for (const k in defaults)
            root[group][k] = defaults[k];
    }

    // kept in step by hand, tests/check_settings.py fails if they drift
    readonly property var defaults: ({
        appearance: { accent: "wallpaper", hue: 186, inkOpacity: 0.97, light: 1.0, clock24h: true, clockSeconds: false,
                      musicInk: true, musicInkGain: 1.0 },
        motion: { speed: 1.0, bounce: 0.5, stretch: 1.0, reduce: false },
        bar: { workspaces: 5, workspaceStyle: "lens", tintIcons: true, windowTitle: true, nowPlaying: true, touchLight: true,
               tray: true, hideOnFullscreen: true, battery: true, layout: true },
        notifications: { dnd: false, timeout: 6, maxToasts: 4, groupByApp: true, images: true },
        desktop: { clock: true, clockCorner: "left", plankton: true, planktonGain: 1.0 },
        wallpaper: { transition: "tide", tideSeconds: 1.5 },
        dashboard: { weatherCity: "", fahrenheit: false, gpu: true },
        player: { trackHue: true, visualizer: true, bars: 48, lyrics: true },
        overview: { live: true },
        lock: { blur: true, media: true, notifications: true, weather: true },
        idle: { lockMinutes: 5, screenOffMinutes: 6, suspendMinutes: 0, caffeine: false, awakeForMusic: true },
        hypr: { gapsIn: 4, gapsOut: 8, border: 1, rounding: 12, dimInactive: true, dimStrength: 0.10,
                shadow: true, glow: true, blur: true, animations: true, animationSpeed: 1.0,
                kbLayout: "", kbVariant: "", kbOptions: "", repeatRate: 35, repeatDelay: 250,
                sensitivity: 0, accelProfile: "flat", naturalScroll: true, tapToClick: true, followMouse: 1 },
        nightLight: { enabled: false, temperature: 4000, scheduled: false, from: "21:00", to: "07:00" },
        recorder: { folder: "", fps: 60, systemAudio: true, microphone: false, cursor: true },
        launcher: { files: true, windows: true, settings: true },
        calendar: { sources: [], days: 14 }
    })
}
