import QtQuick
import qs.core
import qs.components
import qs.services
import qs.modules.settings

Page {
    title: "Panels"
    intro: "The dashboard, the player and the overview."

    Group {
        title: "Dashboard"

        Setting {
            label: "Weather city"
            note: "Any city name, e.g. \"Hamburg\" or \"Lyon, France\". Leave it empty for no weather; your location is never looked up."
            Entry {
                value: Settings.dashboard.weatherCity
                placeholder: "no weather"
                onCommitted: function(v) { Settings.dashboard.weatherCity = v.trim(); }
            }
        }

        Setting {
            label: "Units"
            Choice {
                options: [{ value: false, label: "°C, km/h" }, { value: true, label: "°F, mph" }]
                value: Settings.dashboard.fahrenheit
                onPicked: function(v) { Settings.dashboard.fahrenheit = v; }
            }
        }

        Setting {
            label: "GPU gauge"
            note: "NVIDIA cards, read through nvidia-smi while the dashboard is open."
            Toggle {
                checked: Settings.dashboard.gpu
                onToggled: function(on) { Settings.dashboard.gpu = on; }
            }
        }
    }

    Group {
        title: "Player"

        Setting {
            label: "Colour from the album art"
            note: "The player takes its accent from the cover instead of the wallpaper."
            Toggle {
                checked: Settings.player.trackHue
                onToggled: function(on) { Settings.player.trackHue = on; }
            }
        }

        Setting {
            label: "Visualiser"
            note: "Runs cava only while the player is open and music is playing."
            Toggle {
                checked: Settings.player.visualizer
                onToggled: function(on) { Settings.player.visualizer = on; }
            }
        }

        Setting {
            label: "Bars"
            enabled: Settings.player.visualizer
            Stepper {
                from: 16; to: 96
                value: Settings.player.bars
                onChanged: function(v) { Settings.player.bars = Math.round(v / 4) * 4 || v; }
            }
        }

        Setting {
            label: "Lyrics"
            note: "Synced lyrics from lrclib.net, fetched once per track."
            Toggle {
                checked: Settings.player.lyrics
                onToggled: function(on) { Settings.player.lyrics = on; }
            }
        }
    }

    Group {
        title: "Overview"

        Setting {
            label: "Live window previews"
            note: "Off shows each window's icon and title instead of video."
            Toggle {
                checked: Settings.overview.live
                onToggled: function(on) { Settings.overview.live = on; }
            }
        }
    }

    Group {
        title: "Launcher"

        Setting {
            label: "Files"
            note: "Search your home folder as you type (needs fd, or falls back to find)."
            Toggle {
                checked: Settings.launcher.files
                onToggled: function(on) { Settings.launcher.files = on; }
            }
        }
        Setting {
            label: "Open windows"
            note: "Find a window by its title and jump to it."
            Toggle {
                checked: Settings.launcher.windows
                onToggled: function(on) { Settings.launcher.windows = on; }
            }
        }
        Setting {
            label: "Settings"
            note: "Typing \"gaps\" or \"night light\" opens that setting here."
            Toggle {
                checked: Settings.launcher.settings
                onToggled: function(on) { Settings.launcher.settings = on; }
            }
        }
    }

    Group {
        title: "Screen recording"

        Setting {
            label: "Folder"
            note: "Empty means ~/Videos/Recordings."
            Entry {
                value: Settings.recorder.folder
                placeholder: "~/Videos/Recordings"
                onCommitted: function(v) { Settings.recorder.folder = v.trim(); }
            }
        }
        Setting {
            label: "Frame rate"
            Choice {
                options: [{ value: 30, label: "30" }, { value: 60, label: "60" }, { value: 120, label: "120" }]
                value: Settings.recorder.fps
                onPicked: function(v) { Settings.recorder.fps = v; }
            }
        }
    }

    Group {
        title: "Calendar"

        Setting {
            label: "Calendars"
            note: "One per line: an .ics file, or an https link to one (Google, Nextcloud, Proton and Outlook all give you such a link). Events show in the dashboard."
            Lines {
                value: Settings.calendar.sources
                onCommitted: function(list) { Settings.calendar.sources = list; }
            }
        }
        Setting {
            label: "Days ahead"
            Stepper {
                from: 1; to: 60
                value: Settings.calendar.days
                onChanged: function(v) { Settings.calendar.days = v; }
            }
        }
    }
}
