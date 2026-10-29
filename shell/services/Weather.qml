pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.components

// open-meteo (free, no key, CC BY 4.0). the city comes from settings, never from your ip
Singleton {
    id: root

    property int watchers: 0                 // the dashboard and the lockscreen each count once
    readonly property bool watching: root.watchers > 0
    readonly property string city: Settings.dashboard.weatherCity.trim()
    readonly property bool enabled: root.city !== ""
    readonly property string unit: Settings.dashboard.fahrenheit ? "°F" : "°C"

    property string place: ""                // resolved, e.g. "Hamburg, Germany"
    property real lat: NaN
    property real lon: NaN
    property var current: null               // { temp, feels, code, isDay, wind, humidity }
    property var days: []                    // [{ date, max, min, code, rain }]
    property var hours: []                   // the next 24: [{ time, temp, code, rain, isDay }]
    property double fetchedAt: 0
    property string error: ""
    readonly property bool busy: geo.running || fc.running
    readonly property int maxAgeMs: 30 * 60 * 1000

    FileView {
        id: cache
        path: Paths.stateDir + "/weather.json"
        printErrors: false
        onLoaded: {
            try {
                const c = JSON.parse(this.text());
                if (c.city !== root.city) return;          // a different city: start over
                root.place = c.place || "";
                root.lat = c.lat; root.lon = c.lon;
                root.current = c.current || null;
                root.days = c.days || [];
                root.hours = c.hours || [];
                root.fetchedAt = c.fetchedAt || 0;
            } catch (e) { /* a broken cache is just no cache */ }
            root.maybeRefresh();
        }
        onLoadFailed: root.maybeRefresh()
    }

    function save(): void {
        cache.setText(JSON.stringify({
            city: root.city, place: root.place, lat: root.lat, lon: root.lon,
            current: root.current, days: root.days, hours: root.hours, fetchedAt: root.fetchedAt
        }));
    }

    onWatchingChanged: root.maybeRefresh()
    onCityChanged: {
        root.place = ""; root.lat = NaN; root.lon = NaN;
        root.current = null; root.days = []; root.hours = []; root.fetchedAt = 0;
        root.maybeRefresh();
    }

    function maybeRefresh(): void {
        if (!root.watching || !root.enabled || root.busy) return;
        if (Date.now() - root.fetchedAt < root.maxAgeMs && root.current && root.hours.length > 0) return;
        root.error = "";
        if (isNaN(root.lat) || isNaN(root.lon)) {
            geo.command = ["curl", "-fsS", "--max-time", "8",
                           "https://geocoding-api.open-meteo.com/v1/search?count=1&language=en&format=json&name="
                           + encodeURIComponent(root.city)];
            geo.running = true;
        } else {
            root.fetchForecast();
        }
    }

    function fetchForecast(): void {
        fc.command = ["curl", "-fsS", "--max-time", "8",
            "https://api.open-meteo.com/v1/forecast"
            + "?latitude=" + root.lat + "&longitude=" + root.lon
            + "&current=temperature_2m,apparent_temperature,weather_code,is_day,wind_speed_10m,relative_humidity_2m"
            + "&hourly=temperature_2m,weather_code,precipitation_probability,is_day"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"
            + "&timezone=auto&forecast_days=5"
            + (Settings.dashboard.fahrenheit ? "&temperature_unit=fahrenheit" : "")];
        fc.running = true;
    }

    Process {
        id: geo
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(this.text).results;
                    if (!r || r.length === 0) {
                        root.error = "no place called “" + root.city + "”";
                        return;
                    }
                    root.lat = r[0].latitude;
                    root.lon = r[0].longitude;
                    root.place = [r[0].name, r[0].country].filter(function(s) { return !!s; }).join(", ");
                    root.fetchForecast();
                } catch (e) {
                    root.error = "geocoding failed";
                }
            }
        }
        onExited: function(code, status) {
            if (code !== 0) root.error = code === 127 ? "curl is not installed" : "offline";
        }
    }

    Process {
        id: fc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text);
                    const c = d.current;
                    root.current = {
                        temp: c.temperature_2m, feels: c.apparent_temperature,
                        code: c.weather_code, isDay: c.is_day === 1,
                        wind: c.wind_speed_10m, humidity: c.relative_humidity_2m
                    };
                    const out = [];
                    for (let i = 0; i < d.daily.time.length; i++) {
                        out.push({
                            date: d.daily.time[i],
                            max: d.daily.temperature_2m_max[i],
                            min: d.daily.temperature_2m_min[i],
                            code: d.daily.weather_code[i],
                            rain: d.daily.precipitation_probability_max
                                  ? d.daily.precipitation_probability_max[i] : null
                        });
                    }
                    root.days = out;
                    // hourly starts at midnight, keep from now on
                    const h = d.hourly || null;
                    const hrs = [];
                    if (h && h.time) {
                        const nowHour = (c.time || "").slice(0, 13);
                        let start = h.time.findIndex(function(s) { return s.slice(0, 13) >= nowHour; });
                        if (start < 0) start = 0;
                        for (let i = start; i < Math.min(h.time.length, start + 25); i++)
                            hrs.push({ time: h.time[i], temp: h.temperature_2m[i], code: h.weather_code[i],
                                       rain: h.precipitation_probability ? h.precipitation_probability[i] : null,
                                       isDay: h.is_day ? h.is_day[i] === 1 : true });
                    }
                    root.hours = hrs;
                    root.fetchedAt = Date.now();
                    root.error = "";
                    root.save();
                } catch (e) {
                    root.error = "unexpected reply from open-meteo";
                }
            }
        }
        onExited: function(code, status) {
            if (code !== 0) root.error = code === 127 ? "curl is not installed" : "offline";
        }
    }

    Timer {
        running: root.watching && root.enabled
        interval: 5 * 60 * 1000
        repeat: true
        onTriggered: root.maybeRefresh()
    }

    function describe(code: int): string {
        switch (code) {
        case 0: return "Clear";
        case 1: return "Mainly clear";
        case 2: return "Partly cloudy";
        case 3: return "Overcast";
        case 45: return "Fog";
        case 48: return "Rime fog";
        case 51: case 53: case 55: return "Drizzle";
        case 56: case 57: return "Freezing drizzle";
        case 61: return "Light rain";
        case 63: return "Rain";
        case 65: return "Heavy rain";
        case 66: case 67: return "Freezing rain";
        case 71: return "Light snow";
        case 73: return "Snow";
        case 75: return "Heavy snow";
        case 77: return "Snow grains";
        case 80: case 81: return "Showers";
        case 82: return "Violent showers";
        case 85: case 86: return "Snow showers";
        case 95: return "Thunderstorm";
        case 96: case 97: case 99: return "Thunderstorm, hail";
        default: return "—";
        }
    }

    function icon(code: int, isDay: bool): string {
        if (code === 0 || code === 1) return isDay ? Icons.sun : Icons.moon;
        if (code === 2) return isDay ? Icons.sunCloud : Icons.moonCloud;
        if (code === 3) return Icons.cloud;
        if (code === 45 || code === 48) return Icons.fog;
        if (code >= 51 && code <= 67) return Icons.rain;
        if (code >= 80 && code <= 82) return Icons.rain;
        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return Icons.snow;
        if (code >= 95) return Icons.storm;
        return Icons.cloud;
    }

}
