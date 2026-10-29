import QtQuick
import Quickshell

// loaded by url so a quickshell built without polkit only loses this, not the shell
Scope {
    Loader {
        source: Qt.resolvedUrl("Agent.qml")
        onStatusChanged: if (this.status === Loader.Error)
            console.warn("noctiluca: no polkit agent: this Quickshell was built without it (scripts/build-quickshell.sh)")
    }
}
