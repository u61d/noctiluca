//@ pragma AppId noctiluca
import QtQuick
import Quickshell
import qs.core
import qs.services
import qs.modules.surface
import qs.modules.wallpaper
import qs.modules.lock
import qs.modules.settings
import qs.modules.capture
import qs.modules.polkit

ShellRoot {
    // don't add `required property var modelData` here. the files declare it themselves and a
    // second one shadows theirs, so the window never gets its screen (the black wallpaper bug)
    Variants {
        model: Quickshell.screens
        Wallpaper {}
    }

    Variants {
        model: Quickshell.screens
        Desktop {}
    }

    Variants {
        model: Quickshell.screens
        Exclusion {}
    }

    Variants {
        model: Quickshell.screens
        Surface {}
    }

    Shortcuts {}

    LazyLoader {
        active: Panels.settingsOpen
        SettingsWindow {}
    }

    Capture {}
    PolkitPrompt {}

    // these have to exist from the start even though nothing binds to them
    readonly property var background: [HyprSettings, Idle, Accent, Notifs, SystemStats, NightLight, Beat, Battery, Keyboard, Recorder]

    // last, so the lockscreen still loads if something above it breaks
    Lock {}
}
