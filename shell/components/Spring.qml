import QtQuick
import qs.core

// retargeting keeps the velocity, so a panel reopened while closing turns around.
// closed-form step instead of euler, so a long frame can't blow it up.
// NumberAnimation rather than FrameAnimation so the test capture can drive it frame by frame.
QtObject {
    id: s

    property real target: 0
    property real value: 0
    property real velocity: 0
    property string kind: "nudge"
    property real omega: Motion.spring(s.kind)[0]
    property real zeta: Motion.spring(s.kind)[1]
    property real epsilon: 0.25

    readonly property bool moving: !s.atRest

    property bool atRest: true
    property real clock: 0
    property real last: 0

    // start at the target, not 0 (a binding here would make every change instant)
    Component.onCompleted: s.value = s.target

    function snap(v: real): void {
        s.atRest = true;
        s.velocity = 0;
        s.target = v;
        s.value = v;
    }

    // don't assign `target` here like snap() does. most targets are bindings and that cuts them,
    // which is how panels piled up with reduce motion on. atRest flips so closing panels still unload.
    function jump(): void {
        s.velocity = 0;
        s.atRest = false;
        s.value = s.target;
        s.atRest = true;
    }

    onTargetChanged: {
        if (Motion.reduced) {
            s.jump();
            return;
        }
        if (Math.abs(s.target - s.value) > s.epsilon * 0.5 || Math.abs(s.velocity) > s.epsilon) {
            if (s.atRest) {
                s.last = 0;
                s.atRest = false;
            }
        } else {
            s.value = s.target;
        }
    }

    onClockChanged: {
        let dt = (s.clock - s.last) / 1000;
        s.last = s.clock;
        if (dt <= 0) return;
        if (dt > 0.05) dt = 0.05;
        s.step(dt);
    }

    function step(dt: real): void {
        const w = s.omega, z = s.zeta;
        const x0 = s.value - s.target, v0 = s.velocity;
        let x, v;
        if (z < 0.999) {
            const wd = w * Math.sqrt(1 - z * z);
            const e = Math.exp(-z * w * dt);
            const c = Math.cos(wd * dt), sn = Math.sin(wd * dt);
            const b = (v0 + z * w * x0) / wd;
            x = e * (x0 * c + b * sn);
            v = e * (v0 * c - (x0 * wd + z * w * b) * sn);
        } else if (z <= 1.001) {
            const e = Math.exp(-w * dt);
            const k = v0 + w * x0;
            x = (x0 + k * dt) * e;
            v = (v0 - w * k * dt) * e;
        } else {
            const r = w * Math.sqrt(z * z - 1);
            const r1 = -z * w + r, r2 = -z * w - r;
            const c2 = (v0 - r1 * x0) / (r2 - r1), c1 = x0 - c2;
            const e1 = Math.exp(r1 * dt), e2 = Math.exp(r2 * dt);
            x = c1 * e1 + c2 * e2;
            v = c1 * r1 * e1 + c2 * r2 * e2;
        }
        if (Math.abs(x) < s.epsilon && Math.abs(v) < s.epsilon * 4) {
            s.velocity = 0;
            s.value = s.target;
            s.atRest = true;
            return;
        }
        s.velocity = v;
        s.value = s.target + x;
    }

    property NumberAnimation driver: NumberAnimation {
        target: s
        property: "clock"
        from: 0
        to: 1e9
        duration: 1e9
        running: !s.atRest
    }
}
