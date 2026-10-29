-- noctiluca-theme re-runs apply() through hyprctl eval when the palette changes
local S = require("modules.settings")

local M = {}

local function rgba(hex, a)
  return string.format("rgba(%s%02x)", hex, math.floor(a * 255 + 0.5))
end
M.rgba = rgba

function M.colors()
  package.loaded["generated.colors"] = nil
  local ok, c = pcall(require, "generated.colors")
  if ok and type(c) == "table" and c.glow then return c end
  return require("palette_default")
end

function M.apply()
  local c = M.colors()
  hl.config({
    general = {
      col = {
        active_border   = rgba(c.glow, 0.60),   -- 1px, no gradient
        inactive_border = rgba(c.line, 0.55),
      },
    },
    decoration = {
      shadow = {
        color          = rgba("000000", 0.42),
        color_inactive = rgba("000000", 0.20),
      },
      glow = {
        color          = rgba(c.glow, 0.28),    -- only the focused window glows
        color_inactive = rgba(c.glow, 0.0),
      },
    },
    misc = {
      background_color = rgba(c.void, 1.0),    -- visible until the shell's wallpaper layer is up
    },
  })
end

return M
