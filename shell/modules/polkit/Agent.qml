import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import Quickshell.Wayland
import qs.core
import qs.components
import qs.services

Scope {
    id: root

    PolkitAgent {
        id: agent
    }

    readonly property var flow: agent.flow
    readonly property bool asking: agent.isActive && root.flow !== null

    PanelWindow {
        id: win

        screen: {
            const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
            for (const s of Quickshell.screens)
                if (s.name === name) return s;
            return Quickshell.screens[0];
        }
        visible: root.asking || sheet.value > 0.001
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: Tokens.nsPrompt
        WlrLayershell.keyboardFocus: root.asking ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Spring {
            id: sheet
            kind: root.asking ? "open" : "close"
            target: root.asking ? 1 : 0
            epsilon: 0.0008
        }

        readonly property real cardW: 460
        readonly property real cardH: body.implicitHeight + 34 + 22 + 30
        readonly property real sheetTop: -22 - (1 - sheet.value) * win.cardH

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.5 * Math.min(1, sheet.value * 1.4)
        }

        Waterline {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: Math.max(80, win.sheetTop + win.cardH + 80)
            drop0: Qt.vector4d((win.width - win.cardW) / 2, win.sheetTop, win.cardW, win.cardH)
            bend0: Qt.vector4d(Math.min(16, Math.abs(sheet.velocity * win.cardH) * 0.005 * Motion.stretch), 0, 0, 0)
            rimBase: 0.45
        }

        Item {
            x: (win.width - win.cardW) / 2 + 30
            y: win.sheetTop + 22 + 30
            width: win.cardW - 60
            opacity: Math.max(0, Math.min(1, (sheet.value - 0.15) / 0.5))

            Column {
                id: body
                width: parent.width
                spacing: 14

                Text {
                    text: "Authentication"
                    font.family: Tokens.fontSans
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    renderType: Text.NativeRendering
                    color: Theme.glow
                }
                TypeText {
                    width: parent.width
                    role: "title"
                    color: Theme.text
                    wrapMode: Text.Wrap
                    font.pixelSize: 15
                    text: root.flow ? root.flow.message : ""
                }
                TypeText {
                    width: parent.width
                    role: "body"
                    color: Theme.mute
                    text: root.flow && root.flow.selectedIdentity
                          ? "as " + root.flow.selectedIdentity.displayName : ""
                    visible: text !== ""
                }

                Field {
                    id: field
                    width: parent.width
                    placeholder: root.flow && root.flow.inputPrompt !== "" ? root.flow.inputPrompt.replace(/:\s*$/, "") : "Password"
                    input.echoMode: root.flow && root.flow.responseVisible ? TextInput.Normal : TextInput.Password
                    input.passwordCharacter: "•"
                    enabled: root.flow !== null && root.flow.isResponseRequired
                    onAccepted: {
                        if (!root.flow) return;
                        root.flow.submit(field.text);
                        field.text = "";
                    }
                    onCancelled: if (root.flow) root.flow.cancelAuthenticationRequest()
                }

                TypeText {
                    width: parent.width
                    role: "body"
                    wrapMode: Text.Wrap
                    text: root.flow ? root.flow.supplementaryMessage : ""
                    visible: text !== ""
                    color: root.flow && root.flow.supplementaryIsError ? Theme.alert : Theme.dim
                }

                Row {
                    spacing: 22
                    anchors.right: parent.right
                    Text {
                        text: "cancel"
                        font.family: Tokens.fontSans
                        font.pixelSize: 13
                        renderType: Text.NativeRendering
                        color: cancelHover.hovered ? Theme.text : Theme.mute
                        HoverHandler { id: cancelHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: if (root.flow) root.flow.cancelAuthenticationRequest() }
                    }
                    Text {
                        text: "authenticate"
                        font.family: Tokens.fontSans
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        renderType: Text.NativeRendering
                        color: okHover.hovered ? Theme.text : Theme.glow
                        HoverHandler { id: okHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: field.accepted() }
                    }
                }
            }
        }

        Connections {
            target: root.flow
            function onIsResponseRequiredChanged() {
                if (root.flow && root.flow.isResponseRequired) field.input.forceActiveFocus();
            }
            function onAuthenticationFailed() { shake.restart(); }
        }
        onVisibleChanged: if (visible) field.input.forceActiveFocus()

        SequentialAnimation {
            id: shake
            NumberAnimation { target: body; property: "x"; to: -10; duration: 50 }
            NumberAnimation { target: body; property: "x"; to: 8; duration: 70 }
            NumberAnimation { target: body; property: "x"; to: -4; duration: 70 }
            NumberAnimation { target: body; property: "x"; to: 0; duration: 80 }
        }
    }
}
