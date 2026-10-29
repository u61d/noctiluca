-- defaults, then local.lua, then whatever the settings app saved

local T = require("tokens")

local S = {
  -- set yours, or binds land on the wrong keys
  kb_layout  = "us",
  kb_variant = "",
  kb_options = "",

  -- highres: the monitor's full resolution at the best refresh it has there.
  -- set an exact mode in local.lua if you want one (`hyprctl monitors all` lists them)
  monitor = { output = "", mode = "highres", position = "0x0", scale = 1 },

  nvidia   = nil,    -- nil = auto-detect the proprietary driver
  glow     = true,   -- the focused window emits a faint glow (decoration.glow)
  shader   = false,  -- optional vignette + static grain screen shader
  vrr      = 0,      -- 0 off, 1 on, 2 fullscreen only
  terminal = "kitty",

  cursor_theme = T.cursor.theme,
  cursor_size  = T.cursor.size,
}

local home = os.getenv("HOME") or ""
S.home    = home
S.bin_dir = home .. "/.local/bin"
S.dir     = (os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")) .. "/hypr"

local ok, o = pcall(require, "local")
if ok and type(o) == "table" then
  for k, v in pairs(o) do
    if type(v) == "table" and type(S[k]) == "table" then
      for kk, vv in pairs(v) do S[k][kk] = vv end
    else
      S[k] = v
    end
  end
end

-- user.lua applies these last, but the layout and anim speed are needed earlier
local state_home = os.getenv("XDG_STATE_HOME")
if not state_home or state_home == "" then state_home = home .. "/.local/state" end
S.state_file = state_home .. "/noctiluca/hypr.lua"
S.user = {}
local oku, u = pcall(dofile, S.state_file)
if oku and type(u) == "table" then
  S.user = u
  local kb = type(u.config) == "table" and type(u.config.input) == "table" and u.config.input or nil
  if kb and type(kb.kb_layout) == "string" and kb.kb_layout ~= "" then
    S.kb_layout  = kb.kb_layout
    S.kb_variant = kb.kb_variant or ""
    S.kb_options = kb.kb_options or ""
  end
end
S.anim_speed = tonumber(S.user.anim_speed) or 1
if S.anim_speed < 0.25 then S.anim_speed = 0.25 end

if S.nvidia == nil then
  local f = io.open("/proc/driver/nvidia/version", "r")
  if f then f:close() end
  S.nvidia = f ~= nil
end

return S
