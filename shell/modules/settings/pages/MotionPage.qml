import QtQuick
import qs.core
import qs.components
import qs.services
import qs.modules.settings

Page {
    title: "Motion"
    intro: "Everything that moves runs on springs: panels, the pools in the bar, notifications. Try a change on the sheet below."

    MotionPreview {
        width: parent.width
        height: 210
    }

    Group {
        title: "Springs"

        Setting {
            label: "Speed"
            Range {
                from: 0.5; to: 2; step: 0.05
                value: Settings.motion.speed
                format: function(v) { return v.toFixed(2) + "×"; }
                onChanged: function(v) { Settings.motion.speed = v; }
            }
        }

        Setting {
            label: "Bounce"
            note: "How far a panel overshoots before it settles. Closing never bounces."
            Range {
                from: 0; to: 1; step: 0.05
                value: Settings.motion.bounce
                format: function(v) { return Math.round(v * 100) + "%"; }
                onChanged: function(v) { Settings.motion.bounce = v; }
            }
        }

        Setting {
            label: "Stretch"
            note: "Moving ink narrows a little and sags at the bottom, like a hanging drop."
            Range {
                from: 0; to: 2; step: 0.05
                value: Settings.motion.stretch
                format: function(v) { return Math.round(v * 100) + "%"; }
                onChanged: function(v) { Settings.motion.stretch = v; }
            }
        }

        Setting {
            label: "Reduce motion"
            note: "Panels appear in place instead of sliding."
            Toggle {
                checked: Settings.motion.reduce
                onToggled: function(on) { Settings.motion.reduce = on; }
            }
        }
    }
}
