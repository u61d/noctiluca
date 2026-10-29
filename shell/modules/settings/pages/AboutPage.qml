import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.components
import qs.services
import qs.modules.settings

Page {
    id: page
    title: "About"
    intro: "NOCTILUCA, a Hyprland desktop written from scratch in Quickshell."

    property string qsInfo: ""
    property string features: ""

    Process {
        running: true
        command: ["sh", "-c", "qs=$(\"$HOME/.local/bin/noctiluca-shell\" --print-qs 2>/dev/null); echo \"$qs\"; "
                 + "d=$(dirname \"$(dirname \"$qs\")\"); cat \"$d/.noctiluca-features\" 2>/dev/null | tr '\\n' ' '"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = this.text.split("\n");
                page.qsInfo = (l[0] || "").trim();
                page.features = (l[1] || "").trim();
            }
        }
    }

    component Fact: Setting {
        property string value: ""
        Text {
            text: parent.parent.value
            font.family: Tokens.fontMono
            font.pixelSize: 12
            renderType: Text.NativeRendering
            color: Theme.dim
            horizontalAlignment: Text.AlignRight
        }
    }

    Group {
        title: "This install"
        Fact { label: "Version"; value: Tokens.version }
        Fact { label: "Quickshell"; value: page.qsInfo || "unknown" }
        Fact { label: "Built with"; value: page.features || "no screencopy (the overview needs a rebuild)" }
        Fact {
            label: "Notifications"
            value: Notifs.busState === "ours" ? "received by this shell"
                 : Notifs.busState === "taken" ? "taken by " + Notifs.busOwner : "not checked yet"
        }
        Fact { label: "Settings file"; value: Settings.path.replace(Paths.home, "~") }
        Fact { label: "Palette"; value: Theme.live ? "from " + Paths.palette.replace(Paths.home, "~") : "built-in" }
    }

    Group {
        title: "Start over"

        Setting {
            label: "Reset everything"
            note: "Every setting on every page goes back to how it shipped. Your wallpapers aren't touched."
            Text {
                text: armed ? "press again to reset" : "reset"
                property bool armed: false
                font.family: Tokens.fontSans
                font.pixelSize: 13
                font.underline: resetHover.hovered
                renderType: Text.NativeRendering
                color: armed ? Theme.alert : Theme.glow
                HoverHandler { id: resetHover; cursorShape: Qt.PointingHandCursor }
                Timer { id: disarm; interval: 4000; onTriggered: parent.armed = false }
                TapHandler {
                    onTapped: {
                        if (!parent.armed) {
                            parent.armed = true;
                            disarm.restart();
                            return;
                        }
                        parent.armed = false;
                        for (const g in Settings.defaults) Settings.reset(g);
                    }
                }
            }
        }
    }
}
