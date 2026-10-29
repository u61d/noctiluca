import QtQuick
import qs.core
import qs.components
import qs.services
import qs.modules.settings

Page {
    title: "Windows"
    intro: "Hyprland's look. Applied to the running compositor straight away and kept for the next login."

    Group {
        title: "Layout"

        Setting {
            label: "Gap between windows"
            Stepper {
                from: 0; to: 40; unit: " px"
                value: Settings.hypr.gapsIn
                onChanged: function(v) { Settings.hypr.gapsIn = v; }
            }
        }

        Setting {
            label: "Gap to the screen edge"
            Stepper {
                from: 0; to: 60; unit: " px"
                value: Settings.hypr.gapsOut
                onChanged: function(v) { Settings.hypr.gapsOut = v; }
            }
        }

        Setting {
            label: "Border"
            Stepper {
                from: 0; to: 6; unit: " px"
                value: Settings.hypr.border
                onChanged: function(v) { Settings.hypr.border = v; }
            }
        }

        Setting {
            label: "Corner radius"
            Stepper {
                from: 0; to: 30; unit: " px"
                value: Settings.hypr.rounding
                onChanged: function(v) { Settings.hypr.rounding = v; }
            }
        }
    }

    Group {
        title: "Effects"

        Setting {
            label: "Dim unfocused windows"
            Toggle {
                checked: Settings.hypr.dimInactive
                onToggled: function(on) { Settings.hypr.dimInactive = on; }
            }
        }

        Setting {
            label: "Dim amount"
            enabled: Settings.hypr.dimInactive
            Range {
                from: 0; to: 0.5; step: 0.01
                value: Settings.hypr.dimStrength
                format: function(v) { return Math.round(v * 100) + "%"; }
                onChanged: function(v) { Settings.hypr.dimStrength = v; }
            }
        }

        Setting {
            label: "Shadows"
            Toggle {
                checked: Settings.hypr.shadow
                onToggled: function(on) { Settings.hypr.shadow = on; }
            }
        }

        Setting {
            label: "Glow on the focused window"
            Toggle {
                checked: Settings.hypr.glow
                onToggled: function(on) { Settings.hypr.glow = on; }
            }
        }

        Setting {
            label: "Blur behind transparent windows"
            note: "The most expensive effect here. Off is a good idea on older GPUs."
            Toggle {
                checked: Settings.hypr.blur
                onToggled: function(on) { Settings.hypr.blur = on; }
            }
        }
    }

    Group {
        title: "Animations"

        Setting {
            label: "Window animations"
            Toggle {
                checked: Settings.hypr.animations
                onToggled: function(on) { Settings.hypr.animations = on; }
            }
        }

        Setting {
            label: "Speed"
            note: "Fades and workspace slides. Hyprland reloads its config to apply this one."
            enabled: Settings.hypr.animations
            Range {
                from: 0.5; to: 2; step: 0.1
                value: Settings.hypr.animationSpeed
                format: function(v) { return v.toFixed(1) + "×"; }
                onChanged: function(v) { Settings.hypr.animationSpeed = v; }
            }
        }
    }
}
