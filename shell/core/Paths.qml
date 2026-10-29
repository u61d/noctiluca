pragma Singleton
import Quickshell

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""

    readonly property string stateDir: {
        const x = Quickshell.env("XDG_STATE_HOME");
        return (x && x.length > 0 ? x : root.home + "/.local/state") + "/noctiluca";
    }

    readonly property string configDir: {
        const x = Quickshell.env("XDG_CONFIG_HOME");
        return (x && x.length > 0 ? x : root.home + "/.config");
    }

    readonly property string cacheDir: {
        const x = Quickshell.env("XDG_CACHE_HOME");
        return (x && x !== "" ? x : root.home + "/.cache") + "/noctiluca";
    }
    readonly property string palette: root.stateDir + "/palette.json"

    readonly property string wallpaperState: root.stateDir + "/wallpaper"

    // plain "file://" + path breaks on # or ? in a file name
    function fileUrl(path: string): string {
        if (!path)
            return "";
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }
}
