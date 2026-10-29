import QtQuick
import qs.core
import qs.components
import qs.services
import qs.modules.settings

Page {
    title: "Bar"
    intro: "The line of ink along the top of the screen and the three pools in it."

    Group {
        Setting {
            label: "Workspaces"
            note: "Lens: the one you're on opens up with its apps. Numbers: the same, numerals only. Motes: just light."
            Choice {
                options: [ { value: "lens", label: "Lens" }, { value: "numbers", label: "Numbers" },
                           { value: "motes", label: "Motes" } ]
                value: Settings.bar.workspaceStyle
                onPicked: function(v) { Settings.bar.workspaceStyle = v; }
            }
        }

        Setting {
            label: "Tint app icons"
            note: "Draw the icons in the lens in the accent colour instead of their own."
            enabled: Settings.bar.workspaceStyle === "lens"
            Toggle {
                checked: Settings.bar.tintIcons
                onToggled: function(on) { Settings.bar.tintIcons = on; }
            }
        }

        Setting {
            label: "Workspaces shown"
            note: "Always at least this many. Higher ones appear while they're in use."
            Stepper {
                from: 1; to: 9
                value: Settings.bar.workspaces
                onChanged: function(v) { Settings.bar.workspaces = v; }
            }
        }

        Setting {
            label: "Window title"
            note: "Next to the workspaces. Click it for the overview."
            Toggle {
                checked: Settings.bar.windowTitle
                onToggled: function(on) { Settings.bar.windowTitle = on; }
            }
        }

        Setting {
            label: "Now playing"
            note: "The centre pool shows the track while music plays. Volume changes show there either way."
            Toggle {
                checked: Settings.bar.nowPlaying
                onToggled: function(on) { Settings.bar.nowPlaying = on; }
            }
        }

        Setting {
            label: "Tray"
            note: "Icons of apps running in the background. Left click opens the app, right click its menu."
            Toggle {
                checked: Settings.bar.tray
                onToggled: function(on) { Settings.bar.tray = on; }
            }
        }

        Setting {
            label: "Keyboard layout"
            note: "Shown when you have two layouts or more (Input page). Click it, or Super+Ctrl+Space, to switch."
            Toggle {
                checked: Settings.bar.layout
                onToggled: function(on) { Settings.bar.layout = on; }
            }
        }

        Setting {
            label: "Battery"
            note: "Laptops only; on a desktop there's nothing to show."
            Toggle {
                checked: Settings.bar.battery
                onToggled: function(on) { Settings.bar.battery = on; }
            }
        }

        Setting {
            label: "Get out of the way of fullscreen"
            note: "The ink draws up into the edge over a fullscreen window. Touch the top edge, or open any panel, to bring it back."
            Toggle {
                checked: Settings.bar.hideOnFullscreen
                onToggled: function(on) { Settings.bar.hideOnFullscreen = on; }
            }
        }

        Setting {
            label: "Light on click"
            note: "Clicking the bar, a panel or a workspace sends a ripple of light along the ink. Off: nothing moves when you click."
            Toggle {
                checked: Settings.bar.touchLight
                onToggled: function(on) { Settings.bar.touchLight = on; }
            }
        }
    }
}
