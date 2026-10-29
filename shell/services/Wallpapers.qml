pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// setting one goes through `noctiluca-wallpaper --set` so the palette and image can't disagree
Singleton {
    id: root

    readonly property string current: root._current
    property string _current: ""

    property string preview: ""
    property real previewHue: -1          // < 0 = unknown, keep the committed palette
    property bool previewMono: false       // the image is black and white: a silver accent

    readonly property string shown: root.preview !== "" ? root.preview : root._current

    property var list: []                 // [{path, name, mtime, bytes, current}]
    property var dirs: []
    property bool scanning: false
    property string error: ""

    readonly property int count: root.list.length

    function indexOf(path: string): int {
        for (let i = 0; i < root.list.length; i++)
            if (root.list[i].path === path)
                return i;
        return -1;
    }

    function set(path: string): void {
        if (path === "")
            return;
        Quickshell.execDetached(["noctiluca-wallpaper", "--set", path]);
    }

    // keep the preview up until the new palette lands so the old accent doesn't flash back.
    // dropped after a few seconds if the image gets refused
    property string committing: ""

    function commit(path: string): void {
        if (path === "") return;
        root.committing = path;
        root.set(path);
        commitTimeout.restart();
    }

    function cancel(): void {
        if (root.committing !== "") return;      // a commit in flight keeps its preview
        root.clearPreview();
    }

    onCurrentChanged: {
        if (root.committing !== "" && root.current === root.committing) {
            root.committing = "";
            commitTimeout.stop();
            root.clearPreview();
        }
    }

    Timer {
        id: commitTimeout
        interval: 4000
        onTriggered: {
            if (root.committing === "") return;
            console.warn("noctiluca: wallpaper was not applied:", root.committing);
            root.committing = "";
            root.clearPreview();
        }
    }

    Binding {
        target: Theme
        property: "previewHue"
        value: root.previewHue
        when: root.preview !== "" && root.previewHue >= 0
    }
    Binding {
        target: Theme
        property: "previewMono"
        value: root.previewMono
        when: root.preview !== "" && root.previewHue >= 0
    }

    function random(): void {
        Quickshell.execDetached(["noctiluca-wallpaper", "--random"]);
    }

    function refresh(): void {
        if (scan.running)
            return;
        root.scanning = true;
        scan.running = true;
    }

    // same extraction as the real palette, so the preview colour is the final one
    function previewOf(path: string): void {
        root.preview = path;
        root.previewHue = -1;
        hue.candidate = path;
        hue.running = false;
        hue.running = true;
    }

    function clearPreview(): void {
        root.preview = "";
        root.previewHue = -1;
        hue.candidate = "";
        hue.running = false;
    }

    FileView {
        id: file
        path: Paths.wallpaperState
        watchChanges: true

        onFileChanged: this.reload()
        onLoadFailed: root._current = ""
        onLoaded: root._current = this.text().trim()
    }

    Process {
        id: scan
        command: ["noctiluca-wallpaper", "--list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const doc = JSON.parse(this.text);
                    if (doc.schema !== 1)
                        throw new Error("unsupported schema " + doc.schema);
                    root.list = doc.wallpapers || [];
                    root.dirs = doc.dirs || [];
                    root.error = root.list.length > 0 ? ""
                        : "No images found. Put some in " + (root.dirs[0] || "~/Pictures/wallpapers")
                          + ", or set NOCTILUCA_WALLPAPERS.";
                } catch (e) {
                    root.list = [];
                    root.error = "noctiluca-wallpaper --list: " + e.message;
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() !== "")
                    root.error = this.text.trim();
            }
        }
        onExited: function(code, status) {
            root.scanning = false;
            if (code !== 0 && root.error === "")
                root.error = "noctiluca-wallpaper exited " + code
                           + (code === 127 ? " (not on PATH: is NOCTILUCA installed?)" : "");
        }
    }

    Process {
        id: hue
        property string candidate: ""
        command: ["noctiluca-palette", "--image", hue.candidate, "--hue-only"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const doc = JSON.parse(this.text);
                    // too late, selection moved on
                    if (hue.candidate === root.preview && doc.hue !== undefined) {
                        root.previewMono = doc.mono === true;
                        root.previewHue = doc.hue;
                    }
                } catch (e) {
                    root.previewHue = -1;
                }
            }
        }
    }
}
