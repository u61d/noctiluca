pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.core

Singleton {
    id: root

    property string current: ""

    property string launcherMode: "apps"

    property var trayItem: null
    function openTray(item: var): void {
        root.trayItem = item;
        root.current = root.current === "tray" && root.trayItem === item ? "" : "tray";
    }

    readonly property bool isOpen: root.current !== ""

    property bool settingsOpen: false
    property string settingsPage: "look"
    function openSettings(page: string): void {
        root.settingsPage = page;
        root.settingsOpen = true;
    }

    function anchorOf(name: string): string {
        switch (name) {
        case "control":
        case "dashboard":
        case "power":
        case "network":
        case "bluetooth":
        case "mixer":
        case "tray":
            return "right";
        case "":
            return "";
        default:
            return "centre";
        }
    }

    readonly property string screenName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""

    function show(name: string): void {
        root.current = name;
    }

    function toggle(name: string): void {
        root.current = root.current === name ? "" : name;
    }

    function close(): void {
        root.current = "";
    }

    function openLauncher(mode: string): void {
        if (root.current === "launcher" && root.launcherMode === mode) {
            root.current = "";
            return;
        }
        root.launcherMode = mode;
        root.current = "launcher";
    }
}
