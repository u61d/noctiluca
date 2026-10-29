local T = require("tokens")
local S = require("modules.settings")

hl.config({
  decoration = {
    rounding = T.radius.field,             -- 12: windows use the `field` radius
    rounding_power = 2,
    active_opacity = 1.0,
    inactive_opacity = 1.0,

    dim_inactive = true,
    dim_strength = 0.10,

    blur = {
      enabled = true,
      size = 5,
      passes = 2,
      new_optimizations = true,
      xray = false,
      noise = 0.012,
      contrast = 0.89,
      brightness = 0.85,                   -- a bit darker than neutral
      vibrancy = 0.0,                      -- no saturation boost behind the glass
      popups = false,
    },

    shadow = {
      enabled = true,
      range = 28,
      render_power = 3,
      offset = { 0, 8 },
    },

    glow = {
      enabled = S.glow,
      range = 18,
      render_power = 4,
    },
  },
})

if S.shader then
  hl.config({ decoration = { screen_shader = S.dir .. "/shaders/vignette-grain.frag" } })
end
