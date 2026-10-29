pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.core

// nodes only have live properties while tracked, so track all of them while the mixer is up
Singleton {
    id: root

    property int watchers: 0
    readonly property var nodes: Pipewire.ready && Pipewire.nodes ? Pipewire.nodes.values : []

    readonly property var outputs: root.nodes.filter(function(n) { return n && n.audio && n.isSink && !n.isStream; })
    readonly property var inputs: root.nodes.filter(function(n) { return n && n.audio && !n.isSink && !n.isStream; })
    readonly property var playing: root.nodes.filter(function(n) { return n && n.audio && n.isStream && !n.isSink; })
    readonly property var listening: root.nodes.filter(function(n) { return n && n.audio && n.isStream && n.isSink; })

    PwObjectTracker {
        objects: root.watchers > 0 ? root.outputs.concat(root.inputs, root.playing, root.listening) : []
    }

    function label(n: var): string {
        if (!n) return "";
        const p = n.properties || {};
        return n.isStream ? (p["application.name"] || n.description || n.name || "")
                          : (n.description || n.nickname || n.name || "");
    }
    function detail(n: var): string {
        const p = (n && n.properties) || {};
        const m = p["media.name"] || "";
        return m !== "" && m !== root.label(n) ? m : "";
    }
    function iconName(n: var): string {
        const p = (n && n.properties) || {};
        return p["application.icon-name"] || (p["application.process.binary"] || "").toLowerCase()
            || (p["application.name"] || "").toLowerCase();
    }

    function setVolume(n: var, v: real): void {
        if (n && n.audio) n.audio.volume = Math.max(0, Math.min(1.5, v));
    }
    function toggleMute(n: var): void {
        if (n && n.audio) n.audio.muted = !n.audio.muted;
    }
    function useOutput(n: var): void { Pipewire.preferredDefaultAudioSink = n; }
    function useInput(n: var): void { Pipewire.preferredDefaultAudioSource = n; }
}
