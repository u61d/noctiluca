local S = require("modules.settings")

-- our scripts are in ~/.local/bin
local path = os.getenv("PATH") or "/usr/local/bin:/usr/bin:/bin"
if not path:find(S.bin_dir, 1, true) then
  hl.env("PATH", S.bin_dir .. ":" .. path)
end

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

hl.env("XCURSOR_THEME", S.cursor_theme)
hl.env("XCURSOR_SIZE", tostring(S.cursor_size))
hl.env("HYPRCURSOR_THEME", S.cursor_theme)
hl.env("HYPRCURSOR_SIZE", tostring(S.cursor_size))

hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- proprietary driver, from the hyprland wiki
if S.nvidia then
  hl.env("LIBVA_DRIVER_NAME", "nvidia")
  hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
  hl.env("GBM_BACKEND", "nvidia-drm")
end
