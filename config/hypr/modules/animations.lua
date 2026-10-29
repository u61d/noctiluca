-- same durations and curves as the shell (design/tokens.json).
-- speed is in tenths of a second; springs ignore it but it has to be > 0
local T = require("tokens")
local S = require("modules.settings")

hl.config({ animations = { enabled = true, workspace_wraparound = false } })

local function bez(leaf, curve, dur, style)
  hl.animation({ leaf = leaf, enabled = true, speed = T.speed[dur] / S.anim_speed, bezier = "noct-" .. curve, style = style })
end

local function spr(leaf, spring, style)
  hl.animation({ leaf = leaf, enabled = true, speed = 1, spring = "noct-" .. spring, style = style })
end

local function off(leaf)
  hl.animation({ leaf = leaf, enabled = false })
end

bez("global", "settle", "base")

spr("windowsIn",   "pane", "popin 94%")
spr("windowsMove", "pane")
bez("windowsOut",  "exit", "quick", "popin 96%")

bez("fade",        "settle", "base")
bez("fadeIn",      "settle", "base")
bez("fadeOut",     "exit",   "quick")
bez("fadeSwitch",  "settle", "quick")
bez("fadeShadow",  "settle", "base")
bez("fadeGlow",    "settle", "smooth")   -- slow on purpose
bez("fadeDim",     "settle", "base")
bez("fadeDpms",    "glide",  "smooth")

bez("layersIn",      "settle", "base",  "fade")
bez("layersOut",     "exit",   "quick", "fade")
bez("fadeLayersIn",  "settle", "base")
bez("fadeLayersOut", "exit",   "quick")
bez("fadePopupsIn",  "settle", "quick")
bez("fadePopupsOut", "exit",   "quick")

-- borderangle loops forever, so it's off
bez("border", "settle", "slow")
off("borderangle")
off("shadowangle")
off("glowangle")

bez("workspaces",       "glide",  "smooth", "slidefade 12%")
bez("specialWorkspace", "settle", "smooth", "slidefadevert 12%")

bez("zoomFactor",   "settle", "quick")
bez("monitorAdded", "settle", "quick")
