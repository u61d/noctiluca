import QtQuick
import QtQuick.Effects
import QtQuick.Particles
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd
import qs.core
import qs.components
import qs.services

// greeter.json (written by install-greeter.sh) says who to start with:
//   { "user": "u61d", "session": "Hyprland" }
Scope {
    id: root

    property var users: []               // [{ name, full }]
    property int userIndex: 0
    readonly property var user: root.users.length > 0 ? root.users[root.userIndex] : null
    property var sessions: []            // [{ name, exec }]
    property int sessionIndex: 0
    readonly property var session: root.sessions.length > 0 ? root.sessions[root.sessionIndex] : null
    property var prefs: ({})
    property string host: ""

    FileView {
        path: "/etc/hostname"
        printErrors: false
        onLoaded: root.host = this.text().trim()
    }

    FileView {
        path: Quickshell.shellDir + "/greeter.json"
        printErrors: false
        onLoaded: { try { root.prefs = JSON.parse(this.text()); } catch (e) {} root.pickDefaults(); }
        onLoadFailed: root.pickDefaults()
    }

    Process {
        running: true
        command: ["sh", "-c", "getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 && $7 !~ /(nologin|false)$/ { print $1 \"\\t\" $5 }'"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.users = this.text.split("\n").filter(function(l) { return l !== ""; }).map(function(l) {
                    const f = l.split("\t");
                    return { name: f[0], full: (f[1] || "").split(",")[0] };
                });
                root.pickDefaults();
            }
        }
    }
    Process {
        running: true
        command: ["sh", "-c", "for f in /usr/share/wayland-sessions/*.desktop; do [ -r \"$f\" ] || continue;"
                            + " n=$(sed -n 's/^Name=//p' \"$f\" | head -n1); e=$(sed -n 's/^Exec=//p' \"$f\" | head -n1);"
                            + " [ -n \"$e\" ] && printf '%s\\t%s\\n' \"${n:-$e}\" \"$e\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = this.text.split("\n").filter(function(l) { return l !== ""; }).map(function(l) {
                    const f = l.split("\t");
                    return { name: f[0], exec: f[1] };
                });
                root.sessions = list.length > 0 ? list : [{ name: "Hyprland", exec: "Hyprland" }];
                root.pickDefaults();
            }
        }
    }
    function pickDefaults(): void {
        const u = root.users.findIndex(function(x) { return x.name === root.prefs.user; });
        if (u >= 0) root.userIndex = u;
        const s = root.sessions.findIndex(function(x) { return x.name === root.prefs.session; });
        const h = root.sessions.findIndex(function(x) { return /hyprland/i.test(x.name); });
        root.sessionIndex = s >= 0 ? s : h >= 0 ? h : 0;
    }

    QtObject {
        id: auth
        property string entered: ""
        property bool busy: false
        property bool failed: false
        property string message: ""
        property bool leaving: false

        readonly property string hint: !Greetd.available ? "greetd isn't running this"
            : auth.busy ? "checking…"
            : auth.failed ? (auth.message !== "" ? auth.message : "wrong password")
            : ""

        function submit(): void {
            if (auth.entered === "" || auth.busy || !root.user || auth.leaving) return;
            auth.busy = true;
            auth.failed = false;
            Greetd.createSession(root.user.name);          // the password goes in onAuthMessage
        }
        function key(event: var): void {
            if (auth.busy || auth.leaving) { event.accepted = true; return; }
            if (event.key === Qt.Key_Backspace) {
                auth.entered = (event.modifiers & Qt.ControlModifier) ? "" : auth.entered.slice(0, -1);
                auth.failed = false;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                auth.submit();
            } else if (event.key === Qt.Key_Escape) {
                auth.entered = "";
                auth.failed = false;
            } else if (event.key === Qt.Key_Tab) {
                root.userIndex = (root.userIndex + 1) % Math.max(1, root.users.length);
                auth.entered = "";
            } else if (event.text.length > 0 && event.text.charCodeAt(0) >= 0x20) {
                auth.entered += event.text;
                auth.failed = false;
                auth.typed();
            }
            event.accepted = true;
        }
        signal typed()
        signal rejected()
    }

    Connections {
        target: Greetd
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                Greetd.respond(auth.entered);
                auth.entered = "";
            } else if (error) {
                auth.message = message;
            }
        }
        function onAuthFailure(message) {
            auth.busy = false;
            auth.failed = true;
            auth.message = message !== "" ? message.toLowerCase() : "wrong password";
            auth.entered = "";
            Greetd.cancelSession();
            auth.rejected();
        }
        function onError(error) {
            auth.busy = false;
            auth.failed = true;
            auth.message = error;
            auth.entered = "";
            Greetd.cancelSession();
            auth.rejected();
        }
        // greetd wants us gone quickly after launch
        function onReadyToLaunch() {
            auth.busy = false;
            auth.leaving = true;
            handOver.start();
        }
    }
    Timer {
        id: handOver
        interval: Motion.reduced ? 0 : 520
        onTriggered: {
            const exec = root.session ? root.session.exec : "Hyprland";
            // strip the %-codes desktop files may carry
            Greetd.launch(["sh", "-c", "exec " + exec.replace(/%[a-zA-Z]/g, "").trim()]);
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: surface
            required property var modelData
            screen: surface.modelData
            // only the first screen takes the keyboard
            readonly property bool primary: Quickshell.screens.length === 0 || surface.modelData === Quickshell.screens[0]
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "noctiluca-greeter"
            WlrLayershell.keyboardFocus: surface.primary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            color: Theme.surfaceVoid

            Image {
                id: wall
                anchors.fill: parent
                source: Wallpapers.current !== "" ? Paths.fileUrl(Wallpapers.current) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: Math.ceil(surface.width * (surface.screen ? surface.screen.devicePixelRatio || 1 : 1))
                sourceSize.height: Math.ceil(surface.height * (surface.screen ? surface.screen.devicePixelRatio || 1 : 1))
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: wall
                visible: wall.status === Image.Ready
                blurEnabled: true
                blur: tide.value
                blurMax: 56
                brightness: -0.16 * tide.value
                saturation: -0.25 * tide.value
                scale: 1 + 0.035 * tide.value
            }

            Spring {
                id: tide
                kind: auth.leaving ? "close" : "open"
                target: auth.leaving ? 0 : 1
                epsilon: 0.0008
            }
            property real intro: 0
            NumberAnimation on intro { from: 0; to: 1; duration: Motion.reduced ? 0 : Motion.scaled(1900); easing.type: Easing.OutCubic }
            Component.onCompleted: { tide.snap(0); tide.target = Qt.binding(function() { return auth.leaving ? 0 : 1; }); }

            readonly property real sheetH: surface.height + 60
            readonly property real sheetTop: -22 - (1 - tide.value) * surface.sheetH
            readonly property real show: Math.min(surface.intro, Math.max(0, Math.min(1, (tide.value - 0.45) / 0.5)))
            function after(from: real, span: real): real {
                return Math.max(0, Math.min(1, (surface.show - from) / span));
            }

            Pulses { id: pulses }
            Waterline {
                anchors.fill: parent
                drop0: Qt.vector4d(-80, surface.sheetTop, surface.width + 160, surface.sheetH)
                bend0: Qt.vector4d(Math.min(28, Math.abs(tide.velocity * surface.sheetH) * 0.004 * Motion.stretch), 0, 0, 0)
                dropRadius: 40
                ink: Qt.alpha(Theme.surfaceVoid, 0.56)
                inkDeep: Qt.alpha(Qt.darker(Theme.surfaceVoid, 1.5), 0.82)
                glow: auth.failed ? Theme.alert : Theme.glow
                rimBase: 0.3
                pulse0: pulses.p0
                pulse1: pulses.p1
                pulse2: pulses.p2
                pulse3: pulses.p3
                Behavior on glow { ColorAnimation { duration: Motion.base } }
            }

            ParticleSystem { id: sea; running: !Motion.reduced }
            ImageParticle {
                system: sea; groups: ["drift", "spark"]
                source: "qrc:///particleresources/glowdot.png"
                color: Theme.glow; colorVariation: 0.06
                alpha: 0.7; alphaVariation: 0.3
                entryEffect: ImageParticle.Fade
                opacity: surface.show
            }
            ImageParticle {
                system: sea; groups: ["alarm"]
                source: "qrc:///particleresources/glowdot.png"
                color: Theme.alert; alpha: 0.7
                entryEffect: ImageParticle.Fade
            }
            Emitter {
                system: sea; group: "drift"
                x: 0; y: surface.height * 0.3
                width: surface.width; height: surface.height * 0.7
                emitRate: Math.max(4, Math.round(surface.width / 150))
                lifeSpan: 12000; lifeSpanVariation: 4000
                startTime: 10000
                size: 15; sizeVariation: 11; endSize: 4
                velocity: AngleDirection { angle: 270; angleVariation: 20; magnitude: 11; magnitudeVariation: 8 }
            }
            Emitter {
                id: sparks
                system: sea; group: "spark"; enabled: false
                lifeSpan: 2600; lifeSpanVariation: 900
                size: 8; sizeVariation: 5; endSize: 1
                velocity: AngleDirection { angle: 270; angleVariation: 55; magnitude: 46; magnitudeVariation: 30 }
                acceleration: PointDirection { y: -6 }
            }
            Emitter {
                id: scatter
                system: sea; group: "alarm"; enabled: false
                lifeSpan: 1500; lifeSpanVariation: 500
                size: 9; sizeVariation: 4; endSize: 1
                velocity: AngleDirection { angle: 90; angleVariation: 80; magnitude: 70; magnitudeVariation: 40 }
                acceleration: PointDirection { y: 60 }
            }
            Wander { system: sea; groups: ["drift"]; xVariance: 26; pace: 14 }

            readonly property bool wide: surface.width >= 1280 && surface.width > surface.height
            readonly property real margin: Math.round(Math.min(surface.width, surface.height * 1.6) * 0.07)
            readonly property real floor: surface.height - Math.round(surface.height * 0.1)

            SystemClock { id: clock; precision: SystemClock.Minutes }

            BigClock {
                id: big
                x: surface.margin - big.inset
                y: surface.wide ? surface.floor - height : surface.height * 0.12
                now: clock.date
                format: Settings.timeFormat
                size: Math.round(Math.max(140, Math.min(260, surface.width * 0.13)))
                reveal: surface.show
            }

            Item {
                id: who
                visible: surface.primary
                width: Math.min(380, surface.width - surface.margin * 2)
                height: whoCol.implicitHeight
                x: (surface.wide ? surface.width - surface.margin - who.width : surface.margin) + who.shift
                y: surface.wide ? surface.floor - Math.round(big.size * 0.12) - height : big.y + big.height + 64
                opacity: surface.after(0.36, 0.4)
                transform: Translate { y: 24 * (1 - surface.after(0.36, 0.4)) }
                property real shift: 0

                SequentialAnimation {
                    id: shake
                    NumberAnimation { target: who; property: "shift"; to: -12; duration: 45 }
                    NumberAnimation { target: who; property: "shift"; to: 9; duration: 70 }
                    NumberAnimation { target: who; property: "shift"; to: -5; duration: 70 }
                    NumberAnimation { target: who; property: "shift"; to: 0; duration: 60 }
                }

                Column {
                    id: whoCol
                    width: parent.width
                    spacing: 0

                    Flow {
                        width: parent.width
                        spacing: 18
                        Repeater {
                            model: root.users
                            delegate: Text {
                                id: person
                                required property var modelData
                                required property int index
                                readonly property bool chosen: person.index === root.userIndex
                                text: person.modelData.full !== "" ? person.modelData.full : person.modelData.name
                                font.family: Tokens.fontSans
                                font.pixelSize: 17
                                font.weight: person.chosen ? Font.Medium : Font.Normal
                                renderType: Text.NativeRendering
                                color: person.chosen ? Theme.text : personHover.hovered ? Theme.dim : Theme.mute
                                HoverHandler { id: personHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: { root.userIndex = person.index; auth.entered = ""; auth.failed = false; } }
                            }
                        }
                    }
                    Item { width: 1; height: 10 }
                    PassField {
                        id: pass
                        width: parent.width
                        length: auth.entered.length
                        busy: auth.busy
                        failed: auth.failed
                        onAccepted: auth.submit()
                    }
                    Text {
                        width: parent.width
                        topPadding: 10
                        height: 30
                        text: auth.busy || auth.failed || !Greetd.available ? auth.hint
                            : root.users.length > 1 && auth.entered.length === 0 ? "Tab for someone else" : ""
                        font.family: Tokens.fontSans; font.pixelSize: 13
                        renderType: Text.NativeRendering
                        color: auth.failed ? Theme.alert : Theme.mute
                    }
                }
            }

            Row {
                visible: surface.primary
                x: surface.margin
                y: surface.margin * 0.7 + 8
                spacing: 28
                opacity: surface.after(0.6, 0.4)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.host !== ""
                    text: root.host
                    font.family: Tokens.fontSans; font.pixelSize: 14; font.weight: Font.Medium
                    renderType: Text.NativeRendering
                    color: Theme.dim
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.session ? root.session.name : ""
                        font.family: Tokens.fontSans; font.pixelSize: 14
                        renderType: Text.NativeRendering
                        color: sessHover.hovered ? Theme.text : Theme.dim
                    }
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.sessions.length > 1
                        path: Icons.chevronDown; size: 13
                        color: sessHover.hovered ? Theme.text : Theme.mute
                    }
                    HoverHandler { id: sessHover; cursorShape: root.sessions.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor; margin: 6 }
                    TapHandler { onTapped: root.sessionIndex = (root.sessionIndex + 1) % Math.max(1, root.sessions.length) }
                }
            }

            Row {
                visible: surface.primary
                anchors.right: parent.right
                anchors.rightMargin: surface.margin
                y: surface.margin * 0.7 + 8
                spacing: 24
                opacity: surface.after(0.66, 0.34)
                Repeater {
                    model: [
                        { icon: Icons.suspend, label: "Sleep", cmd: ["systemctl", "suspend"] },
                        { icon: Icons.reboot, label: "Restart", cmd: ["systemctl", "reboot"] },
                        { icon: Icons.power, label: "Shut down", cmd: ["systemctl", "poweroff"] }
                    ]
                    delegate: Row {
                        id: pw
                        required property var modelData
                        spacing: 8
                        Icon { anchors.verticalCenter: parent.verticalCenter; path: pw.modelData.icon; size: 15; color: powHover.hovered ? Theme.text : Theme.mute }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: pw.modelData.label
                            font.family: Tokens.fontSans; font.pixelSize: 14
                            renderType: Text.NativeRendering
                            color: powHover.hovered ? Theme.text : Theme.mute
                        }
                        HoverHandler { id: powHover; cursorShape: Qt.PointingHandCursor; margin: 6 }
                        TapHandler { onTapped: Quickshell.execDetached(pw.modelData.cmd) }
                    }
                }
            }

            Connections {
                target: auth
                function onTyped() {
                    const at = pass.mapToItem(surface, pass.beadsX, pass.beadsY);
                    sparks.burst(3, at.x + (Math.random() - 0.5) * 120, at.y);
                    pulses.emit(at.x + (Math.random() - 0.5) * 140, at.y, 0.35);
                }
                function onRejected() {
                    const at = pass.mapToItem(surface, pass.beadsX, pass.beadsY);
                    for (let i = 0; i < 6; i++) scatter.burst(4, at.x + (i - 2.5) * 40, at.y);
                    pulses.emit(at.x, at.y, 1.4);
                    shake.restart();
                }
            }

            Item {
                id: keys
                anchors.fill: parent
                focus: surface.primary
                Keys.onPressed: function(event) { auth.key(event); }
            }
        }
    }
}
