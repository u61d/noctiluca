import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.core
import qs.components
import qs.services

Item {
    id: root

    property var host: null

    readonly property int colDate: 244
    readonly property int colWeather: 292
    readonly property int colMachine: 300
    readonly property int gap: 40

    implicitWidth: root.colDate + root.colWeather + root.colMachine + 2 * root.gap
    implicitHeight: Calendar.enabled ? 476 : 372

    Component.onCompleted: {
        SystemStats.watching = true;
        Weather.watchers++;
    }
    Component.onDestruction: {
        SystemStats.watching = false;
        Weather.watchers = Math.max(0, Weather.watchers - 1);
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    component Caps: Text {
        font.family: Tokens.fontSans
        font.pixelSize: 12
        font.weight: Font.Medium
        renderType: Text.NativeRendering
        color: Theme.mute
    }
    component Mono: Text {
        font.family: Tokens.fontMono
        font.pixelSize: 11
        renderType: Text.NativeRendering
        color: Theme.mute
    }

    component Gauge: Item {
        id: g
        property string label: ""
        property string value: ""
        property string detail: ""
        property bool hot: false
        property alias trace: tr
        width: parent ? parent.width : 300
        height: 66

        Caps {
            y: 2
            text: g.label
        }
        Mono {
            x: 74
            y: 1
            width: g.width - 74 - valueText.implicitWidth - 12
            elide: Text.ElideRight
            text: g.detail
            font.pixelSize: 10
        }
        Text {
            id: valueText
            anchors.right: parent.right
            y: -3
            text: g.value
            font.family: Tokens.fontMono; font.pixelSize: 15
            renderType: Text.NativeRendering
            color: g.hot ? Theme.alert : Theme.text
        }
        Trace {
            id: tr
            y: 22
            width: g.width
            height: 32
            stepMs: SystemStats.interval
            capacity: SystemStats.keep
            color: g.hot ? Theme.alert : Theme.glow
        }
    }

    Item {
        id: dateCol
        width: root.colDate
        height: parent.height

        Caps {
            text: Qt.formatDateTime(clock.date, "dddd")
            color: Theme.glow
        }
        Row {
            y: 14
            spacing: 12
            Text {
                text: Qt.formatDateTime(clock.date, "d")
                font.family: Tokens.fontSans; font.weight: Font.Light; font.pixelSize: 64
                renderType: Text.NativeRendering
                color: Theme.text
            }
            Column {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
                Text {
                    text: Qt.formatDateTime(clock.date, "MMMM")
                    font.family: Tokens.fontSans; font.pixelSize: 16; font.weight: Font.Medium
                    renderType: Text.NativeRendering
                    color: Theme.text
                }
                Mono {
                    text: "Week " + cal.isoWeek(clock.date) + ", " + Qt.formatDateTime(clock.date, "yyyy")
                }
            }
        }

        Item {
            id: cal
            y: 118
            width: parent.width
            height: parent.height - y

            property int offset: 0                 // months from this one
            readonly property date shown: new Date(clock.date.getFullYear(), clock.date.getMonth() + cal.offset, 1)
            readonly property int year: cal.shown.getFullYear()
            readonly property int month: cal.shown.getMonth()
            readonly property bool here: cal.offset === 0
            readonly property int today: clock.date.getDate()
            readonly property int lead: (cal.shown.getDay() + 6) % 7      // Monday first
            readonly property date midnight: new Date(clock.date.getFullYear(), clock.date.getMonth(), clock.date.getDate())

            function isoWeek(d): int {
                const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
                const day = t.getUTCDay() || 7;
                t.setUTCDate(t.getUTCDate() + 4 - day);
                const y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
                return Math.ceil(((t - y0) / 86400000 + 1) / 7);
            }
            function go(n: int): void {
                slideCal.from = n > 0 ? 18 : -18;
                cal.offset += n;
                slideCal.restart();
            }

            Item {
                width: parent.width; height: 18
                Caps {
                    text: Qt.formatDate(cal.shown, "MMMM yyyy")
                    color: cal.here ? Theme.dim : Theme.glow
                    TapHandler { onTapped: cal.offset = 0 }
                    HoverHandler { cursorShape: cal.here ? Qt.ArrowCursor : Qt.PointingHandCursor }
                }
                Row {
                    anchors.right: parent.right
                    y: -3
                    spacing: 4
                    Repeater {
                        model: [-1, 1]
                        delegate: Text {
                            required property int modelData
                            width: 18
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData < 0 ? "‹" : "›"
                            font.family: Tokens.fontSans; font.pixelSize: 16
                            renderType: Text.NativeRendering
                            color: navHover.hovered ? Theme.text : Theme.mute
                            HoverHandler { id: navHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: cal.go(modelData) }
                        }
                    }
                }
            }

            Item {
                id: grid
                y: 26
                width: parent.width
                height: 22 + 6 * 28

                NumberAnimation on x {
                    id: slideCal
                    running: false
                    to: 0
                    duration: Motion.base
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle
                }

                Row {
                    Repeater {
                        model: ["M", "T", "W", "T", "F", "S", "S"]
                        delegate: Text {
                            required property var modelData
                            required property int index
                            width: grid.width / 7
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            font.family: Tokens.fontMono; font.pixelSize: 10
                            renderType: Text.NativeRendering
                            color: index >= 5 ? Qt.alpha(Theme.mute, 0.6) : Theme.mute
                        }
                    }
                }

                // always six weeks so the height doesn't jump between months
                Repeater {
                    model: 42
                    delegate: Item {
                        id: cell
                        required property int index
                        readonly property date when: new Date(cal.year, cal.month, cell.index - cal.lead + 1)
                        readonly property bool inMonth: cell.when.getMonth() === cal.month
                        readonly property bool isToday: cal.here && cell.inMonth && cell.when.getDate() === cal.today
                        readonly property bool past: cell.when < cal.midnight
                        x: (cell.index % 7) * grid.width / 7
                        y: 22 + Math.floor(cell.index / 7) * 28
                        width: grid.width / 7; height: 28

                        Rectangle {
                            anchors.centerIn: parent
                            width: 26; height: 26; radius: 13
                            visible: cell.isToday
                            color: Qt.alpha(Theme.glow, 0.16)
                            border.width: 1
                            border.color: Qt.alpha(Theme.glow, 0.55)
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: parent.height - 5
                            width: 3; height: 3; radius: 1.5
                            visible: cell.inMonth && Calendar.has(cell.when)
                            color: cell.isToday ? Theme.glowHi : Theme.glow
                            opacity: cell.past && !cell.isToday ? 0.45 : 0.9
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 26; height: 26; radius: 13
                            visible: !cell.isToday && agenda.picked !== null && Calendar.key(agenda.picked) === Calendar.key(cell.when)
                            color: "transparent"
                            border.width: 1
                            border.color: Qt.alpha(Theme.glow, 0.4)
                        }
                        TapHandler {
                            enabled: Calendar.enabled
                            onTapped: agenda.picked = cell.isToday ? null : cell.when
                        }
                        Text {
                            anchors.centerIn: parent
                            text: cell.when.getDate()
                            font.family: Tokens.fontMono; font.pixelSize: 11
                            font.weight: cell.isToday ? Font.DemiBold : Font.Normal
                            renderType: Text.NativeRendering
                            color: cell.isToday ? Theme.glowHi
                                 : !cell.inMonth ? Qt.alpha(Theme.mute, 0.28)
                                 : cell.past ? Qt.alpha(Theme.mute, 0.75)
                                 : cell.index % 7 >= 5 ? Theme.mute : Theme.dim
                        }
                    }
                }
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: function(event) { cal.go(event.angleDelta.y > 0 ? -1 : 1); }
            }
        }

        Item {
            id: agenda
            visible: Calendar.enabled
            y: 360
            width: parent.width
            height: parent.height - y

            property var picked: null            // a day clicked in the month, or null for "up next"
            readonly property var list: {
                if (agenda.picked === null) return Calendar.events.slice(0, 3);
                const k = Calendar.key(agenda.picked);
                return Calendar.events.concat([]).filter(function(e) { return Calendar.key(e.start) === k; }).slice(0, 3);
            }

            Row {
                width: parent.width
                spacing: 8
                Caps {
                    text: agenda.picked === null ? "Up next" : Calendar.dayLabel(agenda.picked)
                    color: Theme.glow
                }
                Caps {
                    visible: Calendar.loading || Calendar.error !== ""
                    text: Calendar.loading ? "Reading…" : Calendar.error
                    color: Calendar.error !== "" ? Theme.alert : Theme.mute
                    width: parent.width - 90
                    elide: Text.ElideRight
                }
            }

            Column {
                y: 20
                width: parent.width
                spacing: 4
                Repeater {
                    model: agenda.list
                    delegate: Item {
                        id: ev
                        required property var modelData
                        width: agenda.width; height: 30
                        Mono {
                            width: 54
                            anchors.verticalCenter: parent.verticalCenter
                            text: ev.modelData.allDay ? "all day" : Qt.formatTime(ev.modelData.start, Settings.timeFormat)
                            color: ev.modelData.start <= new Date() && ev.modelData.end > new Date() ? Theme.glowHi : Theme.dim
                        }
                        Rectangle {
                            x: 58; width: 2; height: 22; radius: 1
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.glow
                            opacity: 0.4 + 0.6 / (1 + ev.modelData.source)
                        }
                        Column {
                            x: 68
                            width: parent.width - 68
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                width: parent.width
                                text: ev.modelData.title
                                elide: Text.ElideRight
                                font.family: Tokens.fontSans; font.pixelSize: 13
                                renderType: Text.NativeRendering
                                color: Theme.text
                            }
                            Mono {
                                width: parent.width
                                visible: text !== ""
                                text: [agenda.picked === null ? Calendar.dayLabel(ev.modelData.start) : "", ev.modelData.location]
                                      .filter(function(s) { return s !== ""; }).join(", ")
                                elide: Text.ElideRight
                                font.pixelSize: 10
                                color: Theme.mute
                            }
                        }
                    }
                }
                Mono {
                    visible: agenda.list.length === 0 && !Calendar.loading
                    text: agenda.picked === null ? "Nothing in the next " + Settings.calendar.days + " days." : "Nothing that day."
                }
            }
        }
    }

    Item {
        id: weatherCol
        x: root.colDate + root.gap
        width: root.colWeather
        height: parent.height

        readonly property var now: Weather.current
        readonly property string speedUnit: Settings.dashboard.fahrenheit ? " mph" : " km/h"

        Caps { text: Weather.place !== "" ? Weather.place : "Weather" }

        Text {
            y: 30
            width: parent.width
            visible: !weatherCol.now
            wrapMode: Text.WordWrap
            text: !Weather.enabled ? "Add your city under Settings → Panels to see the weather here."
                : Weather.error !== "" ? "No weather: " + Weather.error + "."
                : "Looking outside…"
            font.family: Tokens.fontSans; font.pixelSize: 13
            renderType: Text.NativeRendering
            color: Theme.dim
        }

        Item {
            anchors.fill: parent
            visible: weatherCol.now !== null

            Row {
                y: 14
                spacing: 14
                Text {
                    text: weatherCol.now ? Math.round(weatherCol.now.temp) + "°" : ""
                    font.family: Tokens.fontSans; font.weight: Font.Light; font.pixelSize: 64
                    renderType: Text.NativeRendering
                    color: Theme.text
                }
                Column {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    spacing: 1
                    Row {
                        spacing: 7
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            path: weatherCol.now ? Weather.icon(weatherCol.now.code, weatherCol.now.isDay) : ""
                            size: 16
                            color: Theme.glow
                        }
                        Text {
                            text: weatherCol.now ? Weather.describe(weatherCol.now.code) : ""
                            font.family: Tokens.fontSans; font.pixelSize: 16; font.weight: Font.Medium
                            renderType: Text.NativeRendering
                            color: Theme.text
                        }
                    }
                    Mono {
                        text: weatherCol.now
                              ? "Feels like " + Math.round(weatherCol.now.feels) + "°, wind "
                                + Math.round(weatherCol.now.wind) + weatherCol.speedUnit
                              : ""
                    }
                }
            }

            Item {
                id: day
                y: 118
                width: parent.width
                height: 92

                readonly property var hours: Weather.hours.slice(0, 25)
                readonly property real lo: day.hours.length ? Math.min.apply(null, day.hours.map(function(h) { return h.temp; })) : 0
                readonly property real hi: day.hours.length ? Math.max.apply(null, day.hours.map(function(h) { return h.temp; })) : 1
                readonly property real span: Math.max(4, day.hi - day.lo)
                readonly property real yTop: 16
                readonly property real yBottom: 58
                function px(i: int): real { return i * day.width / Math.max(1, day.hours.length - 1); }
                function py(t: real): real { return day.yBottom - (t - day.lo) / day.span * (day.yBottom - day.yTop); }
                readonly property int hiAt: day.hours.findIndex(function(h) { return h.temp === day.hi; })
                readonly property int loAt: day.hours.findIndex(function(h) { return h.temp === day.lo; })

                readonly property string line: {
                    const p = day.hours.map(function(h, i) { return { x: day.px(i), y: day.py(h.temp) }; });
                    if (p.length < 2) return "";
                    let d = "M " + p[0].x.toFixed(1) + " " + p[0].y.toFixed(1);
                    for (let i = 0; i < p.length - 1; i++) {
                        const a = p[Math.max(0, i - 1)], b = p[i], c = p[i + 1], e = p[Math.min(p.length - 1, i + 2)];
                        d += " C " + (b.x + (c.x - a.x) / 6).toFixed(1) + " " + (b.y + (c.y - a.y) / 6).toFixed(1)
                           + " " + (c.x - (e.x - b.x) / 6).toFixed(1) + " " + (c.y - (e.y - b.y) / 6).toFixed(1)
                           + " " + c.x.toFixed(1) + " " + c.y.toFixed(1);
                    }
                    return d;
                }

                Repeater {
                    model: day.hours
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property real chance: (modelData.rain || 0) / 100
                        visible: chance >= 0.15
                        x: day.px(index) - 1
                        width: 2; radius: 1
                        height: chance * 22
                        y: day.yBottom + 6 - height
                        color: Theme.glow
                        opacity: 0.18 + chance * 0.3
                    }
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: LinearGradient {
                            x1: 0; y1: day.yTop; x2: 0; y2: day.yBottom + 6
                            GradientStop { position: 0.0; color: Qt.alpha(Theme.glow, 0.18) }
                            GradientStop { position: 1.0; color: Qt.alpha(Theme.glow, 0.0) }
                        }
                        PathSvg { path: day.line === "" ? "" : day.line + " L " + day.width + " " + (day.yBottom + 6) + " L 0 " + (day.yBottom + 6) + " Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(Theme.glow, 0.18); strokeWidth: 4; fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathSvg { path: day.line }
                    }
                    ShapePath {
                        strokeColor: Theme.glow; strokeWidth: 1.4; fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathSvg { path: day.line }
                    }
                }
                Rectangle {
                    y: day.yBottom + 6
                    width: parent.width; height: 1
                    color: Qt.alpha(Theme.line, 0.7)
                }

                Repeater {
                    model: day.hours.length > 1 ? [day.hiAt, day.loAt].filter(function(v, i, a) { return v >= 0 && a.indexOf(v) === i; }) : []
                    delegate: Mono {
                        required property int modelData
                        readonly property bool isHi: modelData === day.hiAt
                        x: Math.max(0, Math.min(day.width - implicitWidth, day.px(modelData) - implicitWidth / 2))
                        y: day.py(day.hours[modelData].temp) - 17
                        text: Math.round(day.hours[modelData].temp) + "°"
                        color: isHi ? Theme.text : Theme.dim
                    }
                }

                Repeater {
                    model: [0, 6, 12, 18, 24].filter(function(i) { return i < day.hours.length; })
                    delegate: Mono {
                        required property int modelData
                        required property int index
                        y: day.yBottom + 12
                        x: index === 0 ? 0 : Math.min(day.width - implicitWidth, day.px(modelData) - implicitWidth / 2)
                        text: modelData === 0 ? "now" : day.hours[modelData].time.slice(11, 13)
                        font.pixelSize: 10
                        color: modelData === 0 ? Theme.glow : Theme.mute
                    }
                }
            }

            Column {
                id: days
                y: 232
                width: parent.width
                spacing: 2

                readonly property var list: Weather.days.slice(1, 5)
                readonly property real lo: days.list.length ? Math.min.apply(null, days.list.map(function(d) { return d.min; })) : 0
                readonly property real hi: days.list.length ? Math.max.apply(null, days.list.map(function(d) { return d.max; })) : 1

                Repeater {
                    model: days.list
                    delegate: Item {
                        id: dayRow
                        required property var modelData
                        width: days.width; height: 24

                        Mono {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            text: Qt.formatDate(new Date(dayRow.modelData.date + "T12:00:00"), "ddd")
                            font.pixelSize: 10; font.letterSpacing: 1
                        }
                        Icon {
                            x: 40
                            anchors.verticalCenter: parent.verticalCenter
                            path: Weather.icon(dayRow.modelData.code, true)
                            size: 15
                            color: Theme.dim
                        }
                        Mono {
                            x: 62; width: 34
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            text: dayRow.modelData.rain !== null && dayRow.modelData.rain >= 30 ? dayRow.modelData.rain + "%" : ""
                            font.pixelSize: 10
                            color: Theme.glow
                        }
                        Mono {
                            x: 102; width: 30
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            text: Math.round(dayRow.modelData.min) + "°"
                            color: Theme.mute
                        }
                        Item {
                            id: track
                            x: 142
                            width: parent.width - 142 - 40
                            height: 4
                            anchors.verticalCenter: parent.verticalCenter
                            Rectangle { anchors.fill: parent; radius: 2; color: Qt.alpha(Theme.line, 0.6) }
                            Rectangle {
                                readonly property real span: Math.max(1, days.hi - days.lo)
                                x: (dayRow.modelData.min - days.lo) / span * track.width
                                width: Math.max(4, (dayRow.modelData.max - dayRow.modelData.min) / span * track.width)
                                height: 4; radius: 2
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: Theme.glowLo }
                                    GradientStop { position: 1; color: Theme.glowHi }
                                }
                            }
                        }
                        Mono {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: Math.round(dayRow.modelData.max) + "°"
                            color: Theme.text
                        }
                    }
                }
            }
        }

        // open-meteo's licence (CC-BY 4.0) wants attribution
        Mono {
            anchors.bottom: parent.bottom
            text: "Weather from open-meteo.com"
            font.pixelSize: 9
            color: Qt.alpha(Theme.mute, 0.6)
            visible: Weather.enabled
        }
    }

    Item {
        id: machine
        x: root.colDate + root.colWeather + 2 * root.gap
        width: root.colMachine
        height: parent.height

        Caps { text: "This machine" }
        Mono {
            anchors.right: parent.right
            text: SystemStats.kernel !== "" ? "linux " + SystemStats.kernel.split("-")[0] : ""
            font.pixelSize: 10
            color: Qt.alpha(Theme.mute, 0.7)
        }

        Column {
            id: gauges
            y: 30
            width: parent.width
            spacing: 4

            Gauge {
                label: "CPU"
                value: Math.round(SystemStats.cpu * 100) + "%"
                detail: [SystemStats.cpuTemp >= 0 ? Math.round(SystemStats.cpuTemp) + "°" : "",
                         SystemStats.cores > 0 ? SystemStats.cores + " threads" : ""]
                        .filter(function(s) { return s !== ""; }).join(", ")
                hot: SystemStats.cpuTemp >= 85
                trace.values: SystemStats.cpuHistory
            }
            Gauge {
                label: "Memory"
                value: Math.round(SystemStats.mem * 100) + "%"
                detail: SystemStats.memTotal > 0 ? SystemStats.bytes(SystemStats.memUsed) + " of " + SystemStats.bytes(SystemStats.memTotal) : ""
                hot: SystemStats.mem >= 0.92
                trace.values: SystemStats.memHistory
            }
            Gauge {
                visible: SystemStats.hasGpu && Settings.dashboard.gpu
                label: "GPU"
                value: Math.round(SystemStats.gpu * 100) + "%"
                detail: [SystemStats.gpuName.replace(/^(GeForce|Radeon)\s+/, ""),
                         SystemStats.gpuTemp >= 0 ? Math.round(SystemStats.gpuTemp) + "°" : "",
                         SystemStats.gpuPower >= 0 ? Math.round(SystemStats.gpuPower) + " W" : ""]
                        .filter(function(s) { return s !== ""; }).join(", ")
                hot: SystemStats.gpuTemp >= 85
                trace.values: SystemStats.gpuHistory
            }
            Gauge {
                id: net
                label: "Network"
                readonly property real peak: Math.max(64 * 1024,
                    Math.max.apply(null, SystemStats.rxHistory.concat(SystemStats.txHistory).concat([0])))
                value: "↓ " + SystemStats.rate(SystemStats.rxRate)
                detail: "↑ " + SystemStats.rate(SystemStats.txRate)
                trace.values: SystemStats.rxHistory
                trace.max: net.peak

                Trace {
                    y: 22
                    width: net.width
                    height: 32
                    stepMs: SystemStats.interval
                    capacity: SystemStats.keep
                    values: SystemStats.txHistory
                    max: net.peak
                    color: Theme.glowLo
                    fillStrength: 0.08
                    dot: false
                }
            }
        }

        Item {
            y: Math.max(gauges.y + gauges.height + 16, parent.height - 26 - (Calendar.enabled ? 104 : 0))
            width: parent.width
            height: 26
            visible: SystemStats.diskTotal > 0

            Caps { text: "Disk" }
            Mono {
                anchors.right: parent.right
                y: -1
                text: SystemStats.bytes(SystemStats.diskUsed) + " of " + SystemStats.bytes(SystemStats.diskTotal)
                font.pixelSize: 10
            }
            Rectangle {
                y: 18
                width: parent.width; height: 3; radius: 1.5
                color: Qt.alpha(Theme.line, 0.6)
                Rectangle {
                    width: parent.width * SystemStats.disk
                    height: parent.height; radius: 1.5
                    color: SystemStats.disk >= 0.9 ? Theme.alert : Theme.glow
                    Behavior on width { NumberAnimation { duration: Motion.slow; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.settle } }
                }
            }
        }
    }
}
