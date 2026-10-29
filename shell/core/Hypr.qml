pragma Singleton
import Quickshell
import Quickshell.Hyprland

// every dispatch is a lua expression in 0.56, and dispatching before the ipc is up does nothing
Singleton {
    id: root

    readonly property bool ready: Hyprland.usingLua

    function luaStr(s: string): string {
        return '"' + String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';
    }

    function dispatch(luaExpression: string): bool {
        if (!Hyprland.usingLua) {
            console.warn("noctiluca: refusing to dispatch before Hyprland reports a Lua config:",
                         luaExpression);
            return false;
        }
        Hyprland.dispatch(luaExpression);
        return true;
    }

    function focusWorkspace(ws): bool {
        const arg = (typeof ws === "number") ? String(ws) : root.luaStr(ws);
        return root.dispatch("hl.dsp.focus({ workspace = " + arg + " })");
    }

    function exec(cmd: string): bool {
        return root.dispatch("hl.dsp.exec_cmd(" + root.luaStr(cmd) + ")");
    }
}
