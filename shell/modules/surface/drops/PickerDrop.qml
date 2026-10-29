import QtQuick
import QtQuick.Effects
import Quickshell
import qs.core
import qs.components
import qs.services

// nothing is saved until enter, so escape has nothing to undo
Item {
    id: root

    property var host: null

    readonly property real cardW: 480
    readonly property real cardH: Math.round(root.cardW * 9 / 16)
    readonly property real spacing: 250          // between the centres of neighbours

    implicitWidth: 1120
    implicitHeight: 64 + root.cardH + 74

    property string query: ""
    readonly property var shown: {
        const q = root.query.toLowerCase();
        if (q === "") return Wallpapers.list;
        return Wallpapers.list.filter(function(w) { return w.name.toLowerCase().indexOf(q) >= 0; });
    }
    readonly property int count: root.shown.length
    readonly property var entry: root.count > 0 ? root.shown[Math.max(0, Math.min(deck.currentIndex, root.count - 1))] : null

    function takeFocus(): void { keys.forceActiveFocus(); }

    Component.onCompleted: Wallpapers.refresh()
    Component.onDestruction: Wallpapers.cancel()

    Connections {
        target: Wallpapers
        function onListChanged() { root.land(Wallpapers.current); }
    }
    function land(path: string): void {
        let at = 0;
        for (let i = 0; i < root.count; i++) if (root.shown[i].path === path) { at = i; break; }
        deck.currentIndex = at;
        deck.positionViewAtIndex(at, PathView.Center);
        root.showEntry();
    }
    onQueryChanged: {
        const keep = root.entry ? root.entry.path : "";
        Qt.callLater(function() { root.land(keep); });
    }

    function showEntry(): void {
        if (root.entry && root.entry.path !== Wallpapers.preview) Wallpapers.previewOf(root.entry.path);
    }
    // so holding an arrow doesn't recolour the desktop twenty times a second
    Timer { id: settle; interval: 140; onTriggered: root.showEntry() }

    function step(n: int): void {
        if (root.count < 2) return;
        if (n > 0) deck.incrementCurrentIndex(); else deck.decrementCurrentIndex();
    }

    function commit(): void {
        if (!root.entry) return;
        Wallpapers.commit(root.entry.path);
        Panels.close();
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(event) {
            switch (event.key) {
            case Qt.Key_Left: root.step(-1); break;
            case Qt.Key_Right: root.step(1); break;
            case Qt.Key_Home: deck.currentIndex = 0; break;
            case Qt.Key_End: deck.currentIndex = Math.max(0, root.count - 1); break;
            case Qt.Key_Return: case Qt.Key_Enter: root.commit(); break;
            case Qt.Key_Backspace: root.query = root.query.slice(0, -1); break;
            case Qt.Key_Escape:
                if (root.query === "") { event.accepted = false; return; }   // the panel closes
                root.query = "";
                break;
            default:
                // h/l/r are keys until you start typing, then they're letters
                if (root.query === "" && !(event.modifiers & Qt.ControlModifier)) {
                    if (event.key === Qt.Key_H) { root.step(-1); break; }
                    if (event.key === Qt.Key_L) { root.step(1); break; }
                    if (event.key === Qt.Key_R) {
                        if (root.count > 1) {
                            let n = deck.currentIndex;
                            while (n === deck.currentIndex) n = Math.floor(Math.random() * root.count);
                            deck.currentIndex = n;
                        }
                        break;
                    }
                }
                if (event.text !== "" && /[\w .\-]/.test(event.text) && !(event.modifiers & Qt.ControlModifier)) {
                    if (event.text === " " && root.query === "") { event.accepted = false; return; }
                    root.query += event.text;
                    break;
                }
                event.accepted = false;
                return;
            }
            event.accepted = true;
        }
    }

    Item {
        id: header
        x: 26
        width: parent.width - 52
        height: 52

        Text {
            id: label
            text: "Wallpaper"
            font.family: Tokens.fontSans; font.pixelSize: 12; font.weight: Font.Medium
            renderType: Text.NativeRendering
            color: Theme.glow
        }
        Text {
            y: 16
            width: parent.width * 0.5
            elide: Text.ElideRight
            text: root.entry ? root.entry.name : root.query !== "" ? "nothing called “" + root.query + "”" : "no wallpapers"
            font.family: Tokens.fontSans; font.pixelSize: 20; font.weight: Font.Medium
            renderType: Text.NativeRendering
            color: Theme.text
        }

        Row {
            anchors.right: parent.right
            y: 4
            spacing: 14
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Wallpapers.previewHue >= 0 ? (Wallpapers.previewMono ? "black and white" : "hue " + Math.round(Wallpapers.previewHue) + "°")
                    : Wallpapers.preview !== "" ? "reading…" : ""
                font.family: Tokens.fontMono; font.pixelSize: 11
                renderType: Text.NativeRendering
                color: Theme.mute
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Repeater {
                    model: [Theme.glowLo, Theme.glow, Theme.glowHi]
                    delegate: Rectangle {
                        required property var modelData
                        width: 22; height: 6; radius: 3
                        color: modelData
                        Behavior on color { ColorAnimation { duration: Motion.drift } }
                    }
                }
            }
        }

        Row {
            anchors.right: parent.right
            y: 26
            spacing: 6
            Text {
                text: root.query !== "" ? "filter" : ""
                font.family: Tokens.fontMono; font.pixelSize: 11
                renderType: Text.NativeRendering
                color: Theme.mute
            }
            Text {
                text: root.query
                font.family: Tokens.fontMono; font.pixelSize: 11
                renderType: Text.NativeRendering
                color: Theme.glowHi
            }
            Rectangle {
                visible: root.query !== ""
                width: 1; height: 13
                color: Theme.glowHi
                SequentialAnimation on opacity {
                    running: root.query !== ""
                    loops: Animation.Infinite
                    NumberAnimation { to: 0; duration: 530 }
                    NumberAnimation { to: 1; duration: 530 }
                }
            }
        }
    }

    PathView {
        id: deck
        y: 64
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: fade
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
        width: parent.width
        height: root.cardH + 24
        model: root.shown
        clip: true

        readonly property int slots: Math.max(1, Math.min(7, root.count))
        pathItemCount: deck.slots
        preferredHighlightBegin: 0.5
        preferredHighlightEnd: 0.5
        highlightRangeMode: PathView.StrictlyEnforceRange
        highlightMoveDuration: Motion.reduced ? 0 : Motion.smooth
        snapMode: PathView.SnapToItem
        interactive: false                 // keys, clicks and the wheel move it

        onCurrentIndexChanged: settle.restart()

        // `dist` is 0 in the middle and 1 at the ends
        readonly property real half: deck.slots * root.spacing / 2
        path: Path {
            startX: deck.width / 2 - deck.half; startY: deck.height / 2
            PathAttribute { name: "dist"; value: 1 }
            PathLine { x: deck.width / 2; y: deck.height / 2 }
            PathAttribute { name: "dist"; value: 0 }
            PathLine { x: deck.width / 2 + deck.half; y: deck.height / 2 }
            PathAttribute { name: "dist"; value: 1 }
        }

        delegate: Item {
            id: card
            required property var modelData
            required property int index
            readonly property real k: (PathView.dist || 0) * deck.slots / 2
            readonly property bool centre: PathView.isCurrentItem
            readonly property bool isSet: card.modelData.current === true || card.modelData.path === Wallpapers.current

            width: root.cardW
            height: root.cardH
            scale: 1 - 0.26 * Math.min(1, card.k) - 0.12 * Math.max(0, Math.min(1, card.k - 1)) - 0.08 * Math.max(0, card.k - 2)
            z: 10 - card.k
            opacity: Math.max(0, 1 - 0.18 * card.k - 0.22 * Math.max(0, card.k - 1.5))

            Image {
                id: img
                anchors.fill: parent
                source: Paths.fileUrl(card.modelData.path)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: 720; sourceSize.height: 405
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: img
                maskEnabled: true
                maskSource: mask
                brightness: -0.16 * Math.min(1.5, card.k)
                saturation: -0.25 * Math.min(1, card.k)
                opacity: img.status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Motion.base } }
            }
            Item {
                id: mask
                anchors.fill: parent
                layer.enabled: true
                visible: false
                Rectangle { anchors.fill: parent; radius: 12; color: "black" }
            }
            Rectangle {
                anchors.fill: parent
                radius: 12
                color: img.status === Image.Ready ? "transparent" : Theme.surfaceSlate
                border.width: 1
                border.color: card.centre ? Qt.alpha(Theme.glowHi, 0.75)
                            : card.isSet ? Qt.alpha(Theme.glow, 0.45) : Qt.rgba(1, 1, 1, 0.07)
                Behavior on border.color { ColorAnimation { duration: Motion.quick } }
            }
            Rectangle {
                visible: card.isSet
                x: 12; y: 12
                width: setLabel.implicitWidth + 16; height: 20; radius: 10
                color: Qt.alpha(Theme.surfaceVoid, 0.72)
                Text {
                    id: setLabel
                    anchors.centerIn: parent
                    text: "current"
                    font.family: Tokens.fontMono; font.pixelSize: 10; font.letterSpacing: 0.6
                    renderType: Text.NativeRendering
                    color: Theme.glowHi
                }
            }

            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: {
                    if (card.centre) root.commit();
                    else deck.currentIndex = card.index;
                }
            }
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(event) {
                const d = event.angleDelta.y !== 0 ? event.angleDelta.y : -event.angleDelta.x;
                root.step(d > 0 ? -1 : 1);
            }
        }
    }

    Item {
        id: fade
        anchors.fill: deck
        layer.enabled: true
        visible: false
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.13; color: "black" }
                GradientStop { position: 0.87; color: "black" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    Filament {
        anchors.horizontalCenter: parent.horizontalCenter
        y: deck.y + deck.height / 2 + root.cardH / 2 + 6
        width: root.cardW * 0.62
        spread: 4
        intensity: root.entry ? 1 : 0
    }

    Item {
        id: ruler
        anchors.horizontalCenter: parent.horizontalCenter
        y: deck.y + deck.height + 18
        width: Math.min(parent.width - 120, Math.max(60, root.count * 14))
        height: 18
        visible: root.count > 1

        Repeater {
            model: root.count <= 60 ? root.count : 0
            delegate: Rectangle {
                required property int index
                readonly property bool here: index === deck.currentIndex
                x: (ruler.width - 2) * index / Math.max(1, root.count - 1) - (here ? 1 : 0)
                y: here ? 2 : 6
                width: here ? 4 : 2; radius: width / 2
                height: here ? 14 : 6
                color: here ? Theme.glowHi : (root.shown[index].current === true || root.shown[index].path === Wallpapers.current) ? Theme.glow : Qt.alpha(Theme.mute, 0.6)
                Behavior on height { NumberAnimation { duration: Motion.quick } }
            }
        }
        Rectangle {
            visible: root.count > 60
            y: 8; width: parent.width; height: 2; radius: 1
            color: Qt.alpha(Theme.line, 0.8)
            Rectangle {
                x: (parent.width - width) * deck.currentIndex / Math.max(1, root.count - 1)
                width: 18; height: 2; radius: 1
                color: Theme.glowHi
                Behavior on x { NumberAnimation { duration: Motion.smooth; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle } }
            }
        }
        TapHandler {
            onTapped: function(point) {
                deck.currentIndex = Math.round(point.position.x / ruler.width * (root.count - 1));
            }
        }
    }
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 26
        y: ruler.y + 1
        visible: root.count > 0
        text: String(deck.currentIndex + 1).padStart(2, "0") + " / " + String(root.count).padStart(2, "0")
        font.family: Tokens.fontMono; font.pixelSize: 11
        renderType: Text.NativeRendering
        color: Theme.dim
    }

    Text {
        anchors.centerIn: deck
        width: deck.width - 160
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        visible: root.count === 0
        text: Wallpapers.scanning ? "looking…"
            : root.query !== "" ? "No wallpaper names contain “" + root.query + "”. Backspace to change it."
            : (Wallpapers.error !== "" ? Wallpapers.error : "No images found.")
              + "\nsearched: " + (Wallpapers.dirs || []).join(", ")
        font.family: Tokens.fontSans; font.pixelSize: 13
        renderType: Text.NativeRendering
        color: Theme.dim
    }
}
