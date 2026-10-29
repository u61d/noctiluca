pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.core

// quickshell only keeps node properties live while they're tracked
Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    readonly property bool ready: Pipewire.ready && root.sink !== null && root.sink.audio !== null
    readonly property real volume: root.ready ? root.sink.audio.volume : 0
    readonly property bool muted: root.ready ? root.sink.audio.muted : false

    readonly property bool micReady: root.source !== null && root.source.audio !== null
    readonly property real micVolume: root.micReady ? root.source.audio.volume : 0
    readonly property bool micMuted: root.micReady ? root.source.audio.muted : false

    readonly property string sinkName: root.sink
        ? (root.sink.description || root.sink.nickname || root.sink.name || "") : ""

    PwObjectTracker {
        objects: [root.sink, root.source].filter(function(o) { return o !== null; })
    }

    function setVolume(v: real) {
        if (!root.ready) return;
        root.sink.audio.volume = Math.min(1.5, Math.max(0, v));
    }

    function changeVolume(delta: real) { root.setVolume(root.volume + delta); }

    function toggleMute() {
        if (!root.ready) return;
        root.sink.audio.muted = !root.sink.audio.muted;
    }

    function toggleMicMute() {
        if (!root.micReady) return;
        root.source.audio.muted = !root.source.audio.muted;
    }
}
