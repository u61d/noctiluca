pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

Singleton {
    id: root

    property var ids: []
    readonly property int keep: 12

    function note(id: string): void {
        if (!id) return;
        root.ids = [id].concat(root.ids.filter(function(x) { return x !== id; })).slice(0, root.keep);
        file.setText(JSON.stringify({ schema: 1, ids: root.ids }));
    }

    FileView {
        id: file
        path: Paths.stateDir + "/recents.json"
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(this.text());
                if (d.schema === 1 && Array.isArray(d.ids)) root.ids = d.ids.slice(0, root.keep);
            } catch (e) {
                root.ids = [];
            }
        }
    }
}
