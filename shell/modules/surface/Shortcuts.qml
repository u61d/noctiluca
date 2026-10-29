import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.core
import qs.services

// lock is in Lock.qml. names come from design/tokens.json and both sides are checked
// against it
Scope {
    component Key: GlobalShortcut {
        appid: Tokens.appId
    }

    Key { name: "launcher"; description: "Noctiluca: launcher"; onPressed: Panels.openLauncher("apps") }
    // a global fired from a release bind only ever sends `released`
    Key {
        name: "launcher-tap"
        description: "Noctiluca: launcher (Super on its own)"
        onReleased: Panels.current === "launcher" ? Panels.close() : Panels.openLauncher("apps")
    }
    Key { name: "clipboard"; description: "Noctiluca: clipboard history"; onPressed: Panels.openLauncher("clipboard") }
    Key { name: "control"; description: "Noctiluca: control center"; onPressed: Panels.toggle("control") }
    Key { name: "dashboard"; description: "Noctiluca: dashboard"; onPressed: Panels.toggle("dashboard") }
    Key { name: "player"; description: "Noctiluca: music player"; onPressed: Panels.toggle("player") }
    Key { name: "wallpaper"; description: "Noctiluca: wallpaper picker"; onPressed: Panels.toggle("picker") }
    Key { name: "overview"; description: "Noctiluca: overview"; onPressed: Panels.toggle("overview") }
    Key { name: "power"; description: "Noctiluca: power menu"; onPressed: Panels.toggle("power") }
    Key { name: "settings"; description: "Noctiluca: settings"; onPressed: Panels.settingsOpen = !Panels.settingsOpen }
    Key { name: "capture"; description: "Noctiluca: screenshot"; onPressed: Panels.toggle("capture") }

    Key {
        name: "notifications"
        description: "Noctiluca: notification history"
        onPressed: {
            Panels.show("control");
            Notifs.markAllSeen();
        }
    }

    Key { name: "brightness-up"; description: "Noctiluca: brightness up"; onPressed: Brightness.step(5) }
    Key { name: "brightness-down"; description: "Noctiluca: brightness down"; onPressed: Brightness.step(-5) }
    Key { name: "media-play"; description: "Noctiluca: play / pause"; onPressed: Players.playPause() }
    Key { name: "media-next"; description: "Noctiluca: next track"; onPressed: Players.next() }
    Key { name: "media-prev"; description: "Noctiluca: previous track"; onPressed: Players.previous() }

    // region the first time, stop the second
    Key { name: "record"; description: "Noctiluca: screen recording"; onPressed: Recorder.recording ? Recorder.stop() : Panels.toggle("record") }
    Key { name: "mixer"; description: "Noctiluca: volume mixer"; onPressed: Panels.toggle("mixer") }
    Key { name: "color-picker"; description: "Noctiluca: colour picker"; onPressed: Picker.pick() }
    Key { name: "emoji"; description: "Noctiluca: emoji"; onPressed: Panels.openLauncher("emoji") }
    Key { name: "layout-next"; description: "Noctiluca: next keyboard layout"; onPressed: Keyboard.next() }
    Key { name: "night-light"; description: "Noctiluca: night light"; onPressed: NightLight.toggle() }
}
