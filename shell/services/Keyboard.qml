pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.core

// hyprland sends `activelayout` on a switch, so reread then instead of polling
Singleton {
    id: root

    property var layouts: []                 // ["us", "de"]
    property var variants: []
    property int index: 0
    property string keymap: ""               // what xkb calls the active one: "German"
    property bool capsLock: false

    readonly property bool multiple: root.layouts.length > 1
    readonly property string code: root.layouts.length > 0 ? root.layouts[Math.min(root.index, root.layouts.length - 1)] : ""
    readonly property string label: root.code.toUpperCase()

    function next(): void {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
    }
    function select(i: int): void {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", String(i)]);
    }

    function refresh(): void {
        if (!devices.running) devices.running = true;
    }

    Process {
        id: devices
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const all = JSON.parse(this.text).keyboards || [];
                    const kb = all.find(function(k) { return k.main; }) || all[0];
                    if (!kb) return;
                    root.layouts = kb.layout.split(",").map(function(s) { return s.trim(); }).filter(function(s) { return s !== ""; });
                    root.variants = (kb.variant || "").split(",");
                    root.index = Math.max(0, kb.active_layout_index || 0);
                    root.keymap = kb.active_keymap || "";
                    root.capsLock = kb.capsLock === true;
                } catch (e) { /* not in Hyprland, or an old hyprctl */ }
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout" || event.name === "configreloaded") root.refresh();
        }
    }
    // a layout typed into settings takes a moment to reach hyprland
    Connections {
        target: Settings.hypr
        function onKbLayoutChanged() { later.restart(); }
        function onKbVariantChanged() { later.restart(); }
    }
    Timer { id: later; interval: 600; onTriggered: root.refresh() }
}
