import QtQuick
import qs.core

Text {
    id: root

    // display | title | body | label | data | datas
    property string role: "body"
    readonly property var style: {
        switch (root.role) {
        case "display": return Tokens.typeDisplay;
        case "title": return Tokens.typeTitle;
        case "label": return Tokens.typeLabel;
        case "data": return Tokens.typeData;
        case "datas": return Tokens.typeDatas;
        default: return Tokens.typeBody;
        }
    }

    font.family: root.style.family
    font.pixelSize: root.style.pixelSize
    font.weight: root.style.weight
    font.letterSpacing: root.style.letterSpacing
    color: Theme.dim
    renderType: Text.NativeRendering    // crisp stems at 1x on a 1080p panel
    antialiasing: true

    Behavior on color {
        ColorAnimation { duration: Motion.drift; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle }
    }
}
