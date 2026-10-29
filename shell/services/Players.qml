pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.core

// mpris with the rough edges filed off:
// - position doesn't update by itself, so it's ticked here, only while shown
// - art url often arrives after the track change
// - active = the last one that was playing, so pausing doesn't jump to another app
Singleton {
    id: root

    readonly property var all: Mpris.players ? Mpris.players.values : []

    property var active: null

    property bool watchingClosely: false

    readonly property bool hasPlayer: root.active !== null
    readonly property bool playing: root.hasPlayer && root.active.isPlaying
    readonly property string title: root.hasPlayer && root.active.trackTitle ? root.active.trackTitle : ""
    readonly property string artist: root.hasPlayer && root.active.trackArtists ? root.active.trackArtists : ""
    readonly property string album: root.hasPlayer && root.active.trackAlbum ? root.active.trackAlbum : ""
    readonly property string artUrl: root.hasPlayer && root.active.trackArtUrl ? root.active.trackArtUrl : ""
    readonly property string identity: root.hasPlayer && root.active.identity ? root.active.identity : ""
    readonly property real length: root.hasPlayer && root.active.lengthSupported ? root.active.length : 0
    readonly property real position: root.hasPlayer && root.active.positionSupported ? root.active.position : 0
    readonly property real progress: root.length > 0 ? Math.min(1, Math.max(0, root.position / root.length)) : 0
    readonly property bool canSeek: root.hasPlayer && root.active.canSeek
    readonly property bool canGoNext: root.hasPlayer && root.active.canGoNext
    readonly property bool canGoPrevious: root.hasPlayer && root.active.canGoPrevious

    // changes once per song, not every metadata update
    readonly property string trackKey: root.title + "\u0000" + root.artist + "\u0000" + root.album

    function pick(player) { if (player) root.active = player; }
    // loopState: 0 off, 1 track, 2 playlist
    readonly property bool shuffleSupported: root.hasPlayer && !!root.active.shuffleSupported
    readonly property bool shuffle: root.hasPlayer && !!root.active.shuffle
    readonly property bool loopSupported: root.hasPlayer && !!root.active.loopSupported
    readonly property int loop: root.hasPlayer && root.active.loopState !== undefined ? root.active.loopState : 0
    function toggleShuffle() { if (root.shuffleSupported) root.active.shuffle = !root.active.shuffle; }
    function cycleLoop() { if (root.loopSupported) root.active.loopState = (root.loop + 1) % 3; }
    function playPause() { if (root.hasPlayer && root.active.canTogglePlaying) root.active.togglePlaying(); }
    function next() { if (root.canGoNext) root.active.next(); }
    function previous() { if (root.canGoPrevious) root.active.previous(); }

    // `position` is writable, seek() is relative
    function seekFraction(f: real) {
        if (!root.canSeek || root.length <= 0) return;
        root.active.position = Math.min(1, Math.max(0, f)) * root.length;
    }

    function reselect() {
        const list = root.all;
        if (!list || list.length === 0) { root.active = null; return; }
        if (root.active) {
            for (const p of list) if (p === root.active) {
                if (root.active.isPlaying) return;       // keep it
                break;
            }
        }
        for (const p of list) if (p && p.isPlaying) { root.active = p; return; }
        let stillThere = false;
        for (const p of list) if (p === root.active) stillThere = true;
        if (!stillThere) root.active = list[0];
    }

    onAllChanged: root.reselect()
    Component.onCompleted: root.reselect()

    FrameAnimation {
        running: root.playing && root.watchingClosely
        onTriggered: if (root.active) root.active.positionChanged()
    }

    // once a second is plenty for the 1px line in the bar
    Timer {
        running: root.playing && !root.watchingClosely
        interval: 1000
        repeat: true
        onTriggered: if (root.active) root.active.positionChanged()
    }

    Timer {
        running: root.all.length > 1
        interval: 2000
        repeat: true
        onTriggered: root.reselect()
    }

    // follows artUrl, which often lands a bit after the track change
    ColorQuantizer {
        id: quantizer
        source: root.artUrl !== "" ? root.artUrl : ""
        depth: 3            // 2^3 = 8 representative colours, plenty to pick a hue from
        rescaleSize: 64     // quantizing a full-size cover is pointlessly slow
    }

    readonly property real artHue: {
        if (!Settings.player.trackHue) return -1;
        if (!quantizer.colors || quantizer.colors.length === 0) return -1;
        return Chroma.hueFrom(quantizer.colors);
    }
    readonly property bool hasArtHue: root.artHue >= 0

    readonly property color accent: root.hasArtHue ? Chroma.glowAt(root.artHue) : Theme.glow
    readonly property color accentHi: root.hasArtHue ? Chroma.glowHiAt(root.artHue) : Theme.glowHi
    readonly property color accentLo: root.hasArtHue ? Chroma.glowLoAt(root.artHue) : Theme.glowLo
}
