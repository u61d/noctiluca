import QtQuick
import qs.core
import qs.components
import qs.services
import qs.modules.settings

Page {
    title: "Lock & idle"
    intro: "When the screen locks and switches off by itself, and what the lockscreen shows."

    Group {
        title: "When idle"

        Setting {
            label: "Lock after"
            Stepper {
                from: 0; to: 120; unit: " min"; zeroText: "never"
                value: Settings.idle.lockMinutes
                onChanged: function(v) { Settings.idle.lockMinutes = v; }
            }
        }

        Setting {
            label: "Screen off after"
            Stepper {
                from: 0; to: 120; unit: " min"; zeroText: "never"
                value: Settings.idle.screenOffMinutes
                onChanged: function(v) { Settings.idle.screenOffMinutes = v; }
            }
        }

        Setting {
            label: "Suspend after"
            Stepper {
                from: 0; to: 240; unit: " min"; zeroText: "never"
                value: Settings.idle.suspendMinutes
                onChanged: function(v) { Settings.idle.suspendMinutes = v; }
            }
        }

        Setting {
            label: "Stay awake while music plays"
            note: "No lock or screen off while a player is playing. Pausing starts the clock again."
            Toggle {
                checked: Settings.idle.awakeForMusic
                onToggled: function(on) { Settings.idle.awakeForMusic = on; }
            }
        }

        Setting {
            label: "Caffeine"
            note: "Keep the screen awake. Also in the control centre."
            Toggle {
                checked: Settings.idle.caffeine
                onToggled: function(on) { Settings.idle.caffeine = on; }
            }
        }
    }

    Group {
        title: "Lockscreen"

        Setting {
            label: "Blur the wallpaper"
            note: "Under the ink. Off leaves it sharp."
            Toggle {
                checked: Settings.lock.blur
                onToggled: function(on) { Settings.lock.blur = on; }
            }
        }

        Setting {
            label: "Music"
            Toggle {
                checked: Settings.lock.media
                onToggled: function(on) { Settings.lock.media = on; }
            }
        }

        Setting {
            label: "Notification count"
            note: "How many arrived, never what they say."
            Toggle {
                checked: Settings.lock.notifications
                onToggled: function(on) { Settings.lock.notifications = on; }
            }
        }

        Setting {
            label: "Weather"
            Toggle {
                checked: Settings.lock.weather
                onToggled: function(on) { Settings.lock.weather = on; }
            }
        }

        Setting {
            label: "Try it"
            note: "Locks now. Have a second TTY open the first time."
            Text {
                text: "lock the screen"
                font.family: Tokens.fontSans
                font.pixelSize: 13
                font.underline: lockHover.hovered
                renderType: Text.NativeRendering
                color: Theme.glow
                HoverHandler { id: lockHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: Session.lock() }
            }
        }
    }
}
