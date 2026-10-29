-- the login screen's own hyprland. greetd runs it as the greeter user; once you log in the
-- greeter quits, this exits and greetd starts your session
local dir = "/usr/share/noctiluca/greeter"

local ok, cfg = pcall(dofile, dir .. "/greeter-local.lua")
if not ok or type(cfg) ~= "table" then cfg = {} end

hl.monitor(cfg.monitor or { output = "", mode = "preferred", position = "auto", scale = 1 })

for k, v in pairs(cfg.env or {}) do hl.env(k, v) end

hl.config({
  input = {
    kb_layout = cfg.kb_layout or "us",
    kb_variant = cfg.kb_variant or "",
    kb_options = cfg.kb_options or "",
    numlock_by_default = true,
  },
  general = { border_size = 0, gaps_in = 0, gaps_out = 0 },
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    force_default_wallpaper = 0,
  },
  animations = { enabled = false },
  cursor = { inactive_timeout = 6 },
})

hl.on("hyprland.start", function()
  hl.exec_cmd("env XDG_STATE_HOME=" .. dir .. "/state /usr/local/lib/noctiluca/quickshell -p " .. dir
    .. "/shell.qml; hyprctl dispatch 'hl.dsp.exit()'")
end)
