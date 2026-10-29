// python3 tests/render_qml.py design/previews/lock.qml out.png --gpu --scene --wait=5000
import QtQuick
import qs.services
import qs.core
import qs.modules.lock

Item {
    width: 1920; height: 1080
    Lock { id: lockItem }
    Component.onCompleted: {
        Session.lockRequested = true;
        lockItem.state.entered = "hunter2!x";
        Settings.lock.weather = true; Weather.current = { temp: 14.2, feels: 13, code: 2, isDay: false, wind: 9, humidity: 70 };
        Wallpapers._current = Qt.resolvedUrl("sea.png").toString().replace("file://", "");
    }
}
