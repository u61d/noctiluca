local T = require("tokens")

-- the shell animates its own layers. no blur either: the ink is nearly opaque and blurring
-- a fullscreen layer costs a pass every frame. add no_screen_share = true to surface if you
-- don't want the bar in screen shares
local POLICY = {
  background = { no_anim = true },
  desktop    = { no_anim = true },
  surface    = { no_anim = true },
  exclusion  = { no_anim = true },
  prompt     = { no_anim = true },
  -- keeps the overlay out of its own screenshot
  capture    = { no_anim = true, no_screen_share = true },
}

for _, layer in ipairs(T.shell.layers) do
  local policy = POLICY[layer]
  if not policy then
    error("rules: no policy for shell layer '" .. layer .. "' (add it to POLICY)")
  end
  local ns = T.shell.appid .. "-" .. layer
  local spec = { name = ns, match = { namespace = "^" .. ns .. "$" } }
  for k, v in pairs(policy) do spec[k] = v end
  hl.layer_rule(spec)
end

-- apps don't get to maximize themselves
hl.window_rule({
  name = "suppress-maximize",
  match = { class = ".*" },
  suppress_event = "maximize",
})

hl.window_rule({
  name = "noctiluca-settings",
  match = { class = "^noctiluca$", title = "^NOCTILUCA Settings$" },
  float = true,
  size = { 920, 640 },
  center = true,
})

hl.window_rule({
  name = "float-utilities",
  match = { class = "^(pavucontrol|org.pulseaudio.pavucontrol|blueman-manager|nm-connection-editor|xdg-desktop-portal-gtk)$" },
  float = true,
  center = true,
})
