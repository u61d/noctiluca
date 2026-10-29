pragma Singleton
import Quickshell
import qs.core

Singleton {
    id: root

    readonly property real speed: Math.max(0.25, Settings.motion.speed)
    readonly property real bounce: Math.max(0, Math.min(1, Settings.motion.bounce))
    readonly property bool reduced: Settings.motion.reduce
    readonly property real stretch: root.reduced ? 0 : Settings.motion.stretch

    function scaled(ms: int): int {
        return Math.round(ms / root.speed);
    }

    readonly property int tick: root.scaled(Tokens.durTick)
    readonly property int quick: root.scaled(Tokens.durQuick)
    readonly property int base: root.scaled(Tokens.durBase)
    readonly property int smooth: root.scaled(Tokens.durSmooth)
    readonly property int slow: root.scaled(Tokens.durSlow)
    readonly property int drift: root.scaled(Tokens.durDrift)
    readonly property int breath: Tokens.durBreath

    readonly property var settle: Tokens.curveSettle
    readonly property var glide: Tokens.curveGlide
    readonly property var exit: Tokens.curveExit
    readonly property var swell: Tokens.curveSwell
    readonly property var linear: Tokens.curveLinear

    readonly property int staggerStep: Tokens.staggerMs
    function stagger(index: int): int {
        return Math.min(index, 8) * root.staggerStep;
    }

    // [omega, zeta]. bounce only loosens the ones allowed to overshoot
    function spring(kind: string): var {
        const t = ({ open: Tokens.springOpen, close: Tokens.springClose, morph: Tokens.springMorph,
                     nudge: Tokens.springNudge, fade: Tokens.springFade })[kind] || Tokens.springNudge;
        let zeta = t[1];
        if (zeta < 1)
            zeta = Math.max(0.42, Math.min(1, zeta + (0.5 - root.bounce) * 0.56));
        return [t[0] * root.speed, zeta];
    }
}
