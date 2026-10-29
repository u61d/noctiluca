pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property var entries: [
        { label: "Accent colour", words: "colour color hue theme wallpaper", page: "look" },
        { label: "Ink opacity", words: "transparency bar", page: "look" },
        { label: "Light", words: "glow brightness rim", page: "look" },
        { label: "24-hour clock", words: "time format am pm seconds", page: "look" },
        { label: "Ink follows the music", words: "music beat visualiser bass", page: "look" },
        { label: "Animation speed", words: "motion springs bounce reduce", page: "motion" },
        { label: "Workspace style", words: "workspaces lens motes numbers icons", page: "bar" },
        { label: "Tray", words: "system tray icons background apps", page: "bar" },
        { label: "Battery in the bar", words: "laptop power", page: "bar" },
        { label: "Hide over fullscreen", words: "fullscreen bar games", page: "bar" },
        { label: "Light on click", words: "click animation ripple pulse touch effect", page: "bar" },
        { label: "Do not disturb", words: "notifications silence dnd", page: "notifications" },
        { label: "Notification timeout", words: "toasts duration", page: "notifications" },
        { label: "Desktop clock", words: "widget plankton", page: "desktop" },
        { label: "Wallpaper transition", words: "tide fade", page: "desktop" },
        { label: "Night light", words: "blue light warm hyprsunset evening schedule temperature", page: "nightlight" },
        { label: "Weather city", words: "weather location dashboard fahrenheit", page: "panels" },
        { label: "Visualiser and lyrics", words: "cava player music lyrics", page: "panels" },
        { label: "Launcher", words: "files windows search", page: "panels" },
        { label: "Screen recording", words: "record video fps folder", page: "panels" },
        { label: "Calendars", words: "calendar events ics google nextcloud", page: "panels" },
        { label: "Lock after", words: "idle lock screen timeout suspend sleep caffeine", page: "lock" },
        { label: "Stay awake while music plays", words: "idle lock music playing media spotify awake", page: "lock" },
        { label: "Lockscreen", words: "lock blur media weather", page: "lock" },
        { label: "Gaps", words: "gaps windows spacing", page: "windows" },
        { label: "Borders and corners", words: "border rounding radius", page: "windows" },
        { label: "Blur and shadows", words: "blur shadow dim inactive", page: "windows" },
        { label: "Window animations", words: "animations speed", page: "windows" },
        { label: "Keyboard layout", words: "keyboard layout language variant us de", page: "input" },
        { label: "Key repeat", words: "keyboard repeat rate delay", page: "input" },
        { label: "Mouse and touchpad", words: "sensitivity acceleration natural scroll tap", page: "input" },
        { label: "About", words: "version doctor", page: "about" }
    ]
}
