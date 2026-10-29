import QtQuick
import qs.core
import qs.components
import qs.services
import qs.modules.settings

Page {
    title: "Night light"
    intro: "Warmer colours for the evening, through hyprsunset. The screen follows the slider as you move it."

    Group {
        Setting {
            label: "Night light"
            note: !NightLight.available ? "hyprsunset isn't installed: sudo pacman -S hyprsunset"
                : Settings.nightLight.scheduled ? "Follows the schedule below; switching it here ends the schedule."
                : "Also in the control centre, and on Super+Ctrl+N."
            enabled: NightLight.available
            Toggle {
                checked: NightLight.active
                onToggled: function(on) { Settings.nightLight.scheduled = false; Settings.nightLight.enabled = on; }
            }
        }

        Setting {
            label: "Warmth"
            note: "Lower is warmer. 6500 K is no change at all."
            enabled: NightLight.available
            Range {
                from: 2000; to: 6000; step: 100
                value: Settings.nightLight.temperature
                format: function(v) { return Math.round(v) + " K"; }
                onChanged: function(v) { Settings.nightLight.temperature = Math.round(v); }
            }
        }
    }

    Group {
        title: "Schedule"

        Setting {
            label: "On a schedule"
            note: "Turns itself on and off at the times below, across midnight if need be."
            enabled: NightLight.available
            Toggle {
                checked: Settings.nightLight.scheduled
                onToggled: function(on) { Settings.nightLight.scheduled = on; }
            }
        }
        Setting {
            label: "From"
            enabled: Settings.nightLight.scheduled
            Entry {
                implicitWidth: 120
                value: Settings.nightLight.from
                placeholder: "21:00"
                onCommitted: function(v) { if (/^\d{1,2}:\d{2}$/.test(v.trim())) Settings.nightLight.from = v.trim(); }
            }
        }
        Setting {
            label: "Until"
            enabled: Settings.nightLight.scheduled
            Entry {
                implicitWidth: 120
                value: Settings.nightLight.to
                placeholder: "07:00"
                onCommitted: function(v) { if (/^\d{1,2}:\d{2}$/.test(v.trim())) Settings.nightLight.to = v.trim(); }
            }
        }
    }
}
