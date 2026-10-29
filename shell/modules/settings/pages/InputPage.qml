import QtQuick
import qs.core
import qs.components
import qs.services
import qs.modules.settings

Page {
    title: "Input"
    intro: "Keyboard, mouse and touchpad. Applied immediately."

    Group {
        title: "Keyboard"

        Setting {
            label: "Layout"
            note: "XKB names, comma separated for several: \"us\", \"de\", \"us,de\". Empty keeps the one from local.lua."
            Entry {
                value: Settings.hypr.kbLayout
                placeholder: "from local.lua"
                onCommitted: function(v) { Settings.hypr.kbLayout = v.trim(); }
            }
        }

        Setting {
            label: "Variant"
            enabled: Settings.hypr.kbLayout !== ""
            Entry {
                value: Settings.hypr.kbVariant
                placeholder: "none"
                onCommitted: function(v) { Settings.hypr.kbVariant = v.trim(); }
            }
        }

        Setting {
            label: "Options"
            note: "e.g. caps:escape, grp:alt_shift_toggle"
            enabled: Settings.hypr.kbLayout !== ""
            Entry {
                value: Settings.hypr.kbOptions
                placeholder: "none"
                onCommitted: function(v) { Settings.hypr.kbOptions = v.trim(); }
            }
        }

        Setting {
            label: "Repeat rate"
            Stepper {
                from: 10; to: 80; unit: "/s"
                value: Settings.hypr.repeatRate
                onChanged: function(v) { Settings.hypr.repeatRate = v; }
            }
        }

        Setting {
            label: "Repeat delay"
            Range {
                from: 150; to: 800; step: 10
                value: Settings.hypr.repeatDelay
                format: function(v) { return Math.round(v) + " ms"; }
                onChanged: function(v) { Settings.hypr.repeatDelay = Math.round(v); }
            }
        }
    }

    Group {
        title: "Pointer"

        Setting {
            label: "Sensitivity"
            Range {
                from: -1; to: 1; step: 0.05
                value: Settings.hypr.sensitivity
                format: function(v) { return (v > 0 ? "+" : "") + v.toFixed(2); }
                onChanged: function(v) { Settings.hypr.sensitivity = v; }
            }
        }

        Setting {
            label: "Acceleration"
            Choice {
                options: [{ value: "flat", label: "Flat" }, { value: "adaptive", label: "Adaptive" }]
                value: Settings.hypr.accelProfile
                onPicked: function(v) { Settings.hypr.accelProfile = v; }
            }
        }

        Setting {
            label: "Focus follows the mouse"
            Choice {
                options: [{ value: 0, label: "Off" }, { value: 1, label: "Always" }, { value: 2, label: "On click" }]
                value: Settings.hypr.followMouse
                onPicked: function(v) { Settings.hypr.followMouse = v; }
            }
        }
    }

    Group {
        title: "Touchpad"

        Setting {
            label: "Natural scrolling"
            Toggle {
                checked: Settings.hypr.naturalScroll
                onToggled: function(on) { Settings.hypr.naturalScroll = on; }
            }
        }

        Setting {
            label: "Tap to click"
            Toggle {
                checked: Settings.hypr.tapToClick
                onToggled: function(on) { Settings.hypr.tapToClick = on; }
            }
        }
    }
}
