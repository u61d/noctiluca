import QtQuick
import qs.core
import qs.components
import qs.services
import qs.modules.settings

Page {
    title: "Notifications"
    intro: "Toasts hang under the clock and drain away; everything is kept in the control centre."

    Group {
        title: "History"

        Setting {
            label: "Group by app"
            note: "In the control centre, one card per app; the rest fold away under the newest."
            Toggle {
                checked: Settings.notifications.groupByApp
                onToggled: function(on) { Settings.notifications.groupByApp = on; }
            }
        }

        Setting {
            label: "Pictures"
            note: "Album covers, screenshots and faces that come with a notification."
            Toggle {
                checked: Settings.notifications.images
                onToggled: function(on) { Settings.notifications.images = on; }
            }
        }
    }

    Group {
        Setting {
            label: "Do not disturb"
            note: "Nothing pops up. Critical ones still do, and everything is still recorded."
            Toggle {
                checked: Settings.notifications.dnd
                onToggled: function(on) { Settings.notifications.dnd = on; }
            }
        }

        Setting {
            label: "Time on screen"
            note: "Unless the app asks for something else. Hovering a toast pauses it."
            Stepper {
                from: 2; to: 30; unit: " s"
                value: Settings.notifications.timeout
                onChanged: function(v) { Settings.notifications.timeout = v; }
            }
        }

        Setting {
            label: "At most on screen"
            Stepper {
                from: 1; to: 8
                value: Settings.notifications.maxToasts
                onChanged: function(v) { Settings.notifications.maxToasts = v; }
            }
        }
    }

    Group {
        title: "Daemon"

        Setting {
            label: Notifs.busState === "taken" ? "Another program is receiving notifications"
                 : Notifs.busState === "ours" ? "This shell receives notifications"
                 : "Not checked yet"
            note: Notifs.busState === "taken"
                  ? Notifs.busOwner + " owns org.freedesktop.Notifications. Stop it and remove it from your autostart; the shell takes over by itself."
                  : "Only one program can be the notification daemon."
            Text {
                text: "send a test"
                font.family: Tokens.fontSans
                font.pixelSize: 13
                font.underline: testHover.hovered
                renderType: Text.NativeRendering
                color: Theme.glow
                HoverHandler { id: testHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: Quickshell.execDetached(["notify-send", "-a", "noctiluca", "Test notification",
                                                       "If you can read this, notifications work."])
                }
            }
        }
    }
}
