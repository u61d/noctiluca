import QtQuick
import qs.core
import qs.components
import qs.services
import qs.modules.settings

Page {
    title: "Desktop"
    intro: "What sits on the wallpaper, under your windows."

    Group {
        title: "Wallpaper"

        Setting {
            label: "Choose a wallpaper"
            note: "Opens the picker. The desktop previews each one as you move through them."
            Text {
                text: "open picker"
                font.family: Tokens.fontSans
                font.pixelSize: 13
                font.underline: pick.hovered
                renderType: Text.NativeRendering
                color: Theme.glow
                HoverHandler { id: pick; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: Panels.show("picker") }
            }
        }

        Setting {
            label: "Transition"
            note: "Tide washes the new image in from the top behind a lit edge."
            Choice {
                options: [{ value: "tide", label: "Tide" }, { value: "fade", label: "Crossfade" }]
                value: Settings.wallpaper.transition
                onPicked: function(v) { Settings.wallpaper.transition = v; }
            }
        }

        Setting {
            label: "Tide length"
            enabled: Settings.wallpaper.transition === "tide"
            Range {
                from: 0.6; to: 3; step: 0.1
                value: Settings.wallpaper.tideSeconds
                format: function(v) { return v.toFixed(1) + " s"; }
                onChanged: function(v) { Settings.wallpaper.tideSeconds = v; }
            }
        }
    }

    Group {
        title: "On the desktop"

        Setting {
            label: "Clock"
            note: "Large, in a lower corner."
            Toggle {
                checked: Settings.desktop.clock
                onToggled: function(on) { Settings.desktop.clock = on; }
            }
        }

        Setting {
            label: "Corner"
            enabled: Settings.desktop.clock
            Choice {
                options: [{ value: "left", label: "Left" }, { value: "right", label: "Right" }]
                value: Settings.desktop.clockCorner
                onPicked: function(v) { Settings.desktop.clockCorner = v; }
            }
        }

        Setting {
            label: "Plankton"
            note: "Points of light along the bottom edge that move with the music. Needs cava."
            Toggle {
                checked: Settings.desktop.plankton
                onToggled: function(on) { Settings.desktop.plankton = on; }
            }
        }

        Setting {
            label: "Plankton brightness"
            enabled: Settings.desktop.plankton
            Range {
                from: 0.2; to: 2; step: 0.05
                value: Settings.desktop.planktonGain
                format: function(v) { return Math.round(v * 100) + "%"; }
                onChanged: function(v) { Settings.desktop.planktonGain = v; }
            }
        }
    }
}
