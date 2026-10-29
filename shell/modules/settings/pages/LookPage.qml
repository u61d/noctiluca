import QtQuick
import qs.core
import qs.components
import qs.services
import qs.modules.settings

Page {
    title: "Look"
    intro: "The accent is the only colour that changes. Everything else stays the same dark neutrals, so text stays readable whatever hue you pick."

    Group {
        title: "Accent"

        Setting {
            label: "Accent colour"
            note: "Take it from the wallpaper, or keep one hue no matter which wallpaper is up."
            Choice {
                options: [{ value: "wallpaper", label: "From wallpaper" }, { value: "fixed", label: "Fixed" }]
                value: Settings.appearance.accent
                onPicked: function(v) { Settings.appearance.accent = v; }
            }
        }

        Setting {
            label: "Hue"
            note: "Kitty, GTK, Qt apps and window borders follow a moment after you let go."
            enabled: Settings.appearance.accent === "fixed"
            Item {
                implicitWidth: 300
                implicitHeight: 34
                Row {
                    id: strip
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: 6
                    Repeater {
                        model: 36
                        delegate: Rectangle {
                            required property int index
                            width: strip.width / 36
                            height: 6
                            color: Chroma.glowAt(index * 10)
                        }
                    }
                }
                Range {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    from: 0; to: 359; step: 1
                    value: Settings.appearance.hue
                    format: function(v) { return Math.round(v) + "°"; }
                    onChanged: function(v) { Settings.appearance.hue = v; }
                }
            }
        }
    }

    Group {
        title: "Ink"

        Setting {
            label: "Ink opacity"
            note: "How much of the wallpaper shows through the bar and the panels."
            Range {
                from: 0.8; to: 1; step: 0.005
                value: Settings.appearance.inkOpacity
                format: function(v) { return Math.round(v * 100) + "%"; }
                onChanged: function(v) { Settings.appearance.inkOpacity = v; }
            }
        }

        Setting {
            label: "Light"
            note: "Brightness of the rim, the glow around the cursor and the touch pulses."
            Range {
                from: 0.3; to: 1.6; step: 0.05
                value: Settings.appearance.light
                format: function(v) { return Math.round(v * 100) + "%"; }
                onChanged: function(v) { Settings.appearance.light = v; }
            }
        }
    }

    Group {
        title: "Clock"

        Setting {
            label: "24-hour clock"
            Toggle {
                checked: Settings.appearance.clock24h
                onToggled: function(on) { Settings.appearance.clock24h = on; }
            }
        }

        Setting {
            label: "Seconds"
            note: "In the bar's clock."
            Toggle {
                checked: Settings.appearance.clockSeconds
                onToggled: function(on) { Settings.appearance.clockSeconds = on; }
            }
        }
    }

    Group {
        title: "Music"

        Setting {
            label: "The ink follows the music"
            note: "While something plays, the rim of the ink brightens with the bass and each beat sends light along the line. Uses cava."
            Toggle {
                checked: Settings.appearance.musicInk
                onToggled: function(on) { Settings.appearance.musicInk = on; }
            }
        }

        Setting {
            label: "Strength"
            enabled: Settings.appearance.musicInk
            Range {
                from: 0.4; to: 2.5; step: 0.05
                value: Settings.appearance.musicInkGain
                format: function(v) { return Math.round(v * 100) + "%"; }
                onChanged: function(v) { Settings.appearance.musicInkGain = v; }
            }
        }
    }
}
