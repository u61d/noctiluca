pragma Singleton
import QtQuick
import Quickshell
import qs.core

Singleton {
    id: root

    readonly property bool active: Settings.appearance.musicInk && Players.playing && !Motion.reduced
    onActiveChanged: {
        if (root.active) {
            Cava.want("ink");
        } else {
            Cava.drop("ink");
            root.glow = 0;
            root.average = 0;
        }
    }
    Component.onCompleted: if (root.active) Cava.want("ink")

    property real glow: 0
    property real average: 0
    property double lastBeat: 0
    signal beat(real strength)

    Connections {
        target: Cava
        enabled: root.active
        function onLevelsChanged() {
            const l = Cava.levels;
            if (!l || l.length === 0) return;
            // bottom sixth of the spectrum is kick and bass
            const n = Math.max(2, Math.floor(l.length / 6));
            let s = 0;
            for (let i = 0; i < n; i++) s += l[i];
            const bass = Math.min(1, s / n * Settings.appearance.musicInkGain);

            // fast up, slow down, so it reads as light and not flicker
            root.glow = bass > root.glow ? root.glow + (bass - root.glow) * 0.6 : root.glow * 0.88;
            root.average = root.average * 0.94 + bass * 0.06;

            const now = Date.now();
            if (bass > root.average * 1.35 + 0.06 && bass > 0.18 && now - root.lastBeat > 190) {
                root.lastBeat = now;
                root.beat(Math.min(1, bass));
            }
        }
    }
}
