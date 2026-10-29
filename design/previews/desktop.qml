// python3 tests/render_qml.py design/previews/desktop.qml out.png --gpu --scene --wait=4000
import QtQuick
import qs.services
import qs.modules.wallpaper

Item {
    width: 1920; height: 1080
    Image { anchors.fill: parent; source: "sea.png" }
    Desktop {
        modelData: ({ name: "DP-1" })
        width: 1920; height: 330
        y: 1080 - 330
    }
    Component.onCompleted: {
        const n = 48, out = [];
        for (let i = 0; i < n; i++) {
            const t = i / (n - 1);
            out.push(Math.max(0, Math.pow(Math.sin(t * 9.0 + 1.2) * 0.5 + 0.5, 3) * (1 - t * 0.5)
                                 + 0.2 * Math.sin(t * 37) * Math.sin(t * 11)));
        }
        Cava.levels = out;
    }
}
