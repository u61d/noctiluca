pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// live changes go through `hyprctl eval "hl.config({...})"`, which refreshes right away
// outside a config load (0.56.2). anim speed is baked into the curves at load, so that one
// does a reload instead.
Singleton {
    id: root

    readonly property var h: Settings.hypr
    readonly property string statePath: Paths.stateDir + "/hypr.lua"
    property bool ready: false

    function lua(v: var): string {
        if (typeof v === "boolean") return v ? "true" : "false";
        if (typeof v === "number") return String(Math.round(v * 1000) / 1000);
        if (typeof v === "string") return JSON.stringify(v);
        const parts = [];
        for (const k in v) parts.push(k + " = " + root.lua(v[k]));
        return "{ " + parts.join(", ") + " }";
    }

    function configTable(): var {
        const h = root.h;
        const input = {
            repeat_rate: h.repeatRate,
            repeat_delay: h.repeatDelay,
            sensitivity: Math.max(-1, Math.min(1, h.sensitivity)),
            accel_profile: h.accelProfile,
            follow_mouse: h.followMouse,
            touchpad: { natural_scroll: h.naturalScroll, tap_to_click: h.tapToClick }
        };
        if (h.kbLayout.trim() !== "") {
            input.kb_layout = h.kbLayout.trim();
            input.kb_variant = h.kbVariant.trim();
            input.kb_options = h.kbOptions.trim();
        }
        return {
            general: { gaps_in: h.gapsIn, gaps_out: h.gapsOut, border_size: h.border },
            decoration: {
                rounding: h.rounding,
                dim_inactive: h.dimInactive,
                dim_strength: h.dimStrength,
                shadow: { enabled: h.shadow },
                glow: { enabled: h.glow },
                blur: { enabled: h.blur }
            },
            animations: { enabled: h.animations },
            input: input
        };
    }

    readonly property string snapshot: JSON.stringify(root.configTable())
    property real appliedSpeed: -1

    onSnapshotChanged: if (root.ready) push.restart()
    Connections {
        target: root.h
        function onAnimationSpeedChanged() { if (root.ready) push.restart(); }
    }

    Timer {
        id: push
        interval: 120
        onTriggered: root.apply()
    }

    function apply(): void {
        const table = root.lua(root.configTable());
        state.setText("-- written by the NOCTILUCA settings app; edit it there\n"
                      + "return { anim_speed = " + root.lua(root.h.animationSpeed) + ", config = " + table + " }\n");
        if (root.appliedSpeed >= 0 && Math.abs(root.appliedSpeed - root.h.animationSpeed) > 0.001) {
            reload.running = true;
        } else {
            evalProc.command = ["hyprctl", "eval", "hl.config(" + table + ")"];
            evalProc.running = true;
        }
        root.appliedSpeed = root.h.animationSpeed;
    }

    FileView {
        id: state
        path: root.statePath
        blockLoading: true
        printErrors: false
    }

    Process {
        id: evalProc
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim();
                if (out !== "" && out !== "ok")
                    console.warn("noctiluca: hyprctl eval:", out);
            }
        }
    }

    Process {
        id: reload
        command: ["hyprctl", "reload"]
    }

    // wait for the settings file, or the first thing we'd do is overwrite the user's hyprland
    // options with the defaults
    Timer {
        interval: 1500
        running: true
        onTriggered: {
            root.appliedSpeed = root.h.animationSpeed;
            root.ready = true;
        }
    }
}
