-- descriptions are "Section: what it does", docs/KEYBINDS.md is generated from them
local T = require("tokens")
local S = require("modules.settings")

local mod = "SUPER"

-- checked against tokens.json, so a typo is an error instead of a dead key
local function shell(name)
  for _, known in ipairs(T.shell.shortcuts) do
    if known == name then
      return hl.dsp.global(T.shell.appid .. ":" .. name)
    end
  end
  error("keybinds: '" .. name .. "' is not in tokens.json shell.shortcuts")
end

local function bind(keys, dispatcher, description, opts)
  local o = { description = description }
  if opts then for k, v in pairs(opts) do o[k] = v end end
  hl.bind(keys, dispatcher, o)
end

bind(mod .. " + space",        shell("launcher"),      "Shell: launcher (apps, calc, commands)")
-- Super tapped on its own. it's a function and not a plain global because hyprland only
-- cancels the release when another bind fired in between (Super+1...) for non-global
-- handlers. a global sent from a release bind arrives as `released`, hence launcher-tap
bind(mod .. " + Super_L",      function() hl.dispatch(shell("launcher-tap")) end,
     "Shell: launcher (tap Super on its own)", { release = true, non_consuming = true })
bind(mod .. " + V",            shell("clipboard"),     "Shell: clipboard history")
bind(mod .. " + A",            shell("control"),       "Shell: control center")
bind(mod .. " + D",            shell("dashboard"),     "Shell: dashboard (calendar, weather, system)")
bind(mod .. " + Tab",          shell("overview"),      "Shell: overview (every workspace, the one you pick large)")
bind(mod .. " + M",            shell("player"),        "Shell: music player")
bind(mod .. " + N",            shell("notifications"), "Shell: notification history")
bind(mod .. " + W",            shell("wallpaper"),     "Shell: wallpaper picker")
bind(mod .. " + escape",       shell("power"),         "Shell: power menu")
bind(mod .. " + CTRL + L",     shell("lock"),          "Shell: lock screen")
bind(mod .. " + I",            shell("settings"),      "Shell: settings")
bind("Print",                  shell("capture"),       "Shell: screenshot")
bind(mod .. " + SHIFT + S",    shell("capture"),       "Shell: screenshot")
bind(mod .. " + SHIFT + R",    shell("record"),        "Shell: screen recording (again to stop)")
bind(mod .. " + SHIFT + C",    shell("color-picker"),  "Shell: pick a colour from the screen")
bind(mod .. " + period",       shell("emoji"),         "Shell: emoji")
bind(mod .. " + SHIFT + A",    shell("mixer"),         "Shell: volume mixer")
bind(mod .. " + CTRL + space", shell("layout-next"),   "Shell: next keyboard layout")
bind(mod .. " + CTRL + N",     shell("night-light"),   "Shell: night light on / off")

bind(mod .. " + Return",       hl.dsp.exec_cmd(S.terminal), "Apps: terminal")

bind(mod .. " + Q",            hl.dsp.window.close(),                              "Window: close")
bind(mod .. " + F",            hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), "Window: fullscreen")
bind(mod .. " + SHIFT + F",    hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }),  "Window: maximize")
bind(mod .. " + T",            hl.dsp.window.float({ action = "toggle" }),         "Window: toggle floating")
bind(mod .. " + C",            hl.dsp.window.center(),                             "Window: center (floating)")
bind(mod .. " + Y",            hl.dsp.window.pin(),                                "Window: pin on all workspaces")
bind(mod .. " + S",            hl.dsp.layout("togglesplit"),                       "Window: toggle split direction")

local dirs = {
  { "h", "left" }, { "j", "down" }, { "k", "up" }, { "l", "right" },
  { "left", "left" }, { "down", "down" }, { "up", "up" }, { "right", "right" },
}
for _, d in ipairs(dirs) do
  bind(mod .. " + " .. d[1],             hl.dsp.focus({ direction = d[2] }),       "Focus: " .. d[2])
  bind(mod .. " + SHIFT + " .. d[1],     hl.dsp.window.move({ direction = d[2] }), "Move window: " .. d[2])
end

for i = 1, 9 do
  bind(mod .. " + " .. i,                hl.dsp.focus({ workspace = i }),          "Workspace: go to " .. i)
  bind(mod .. " + SHIFT + " .. i,        hl.dsp.window.move({ workspace = i }),    "Workspace: send window to " .. i)
end
-- keypad by keycode so num lock doesn't matter
local keypad = { 87, 88, 89, 83, 84, 85, 79, 80, 81 }
for i, code in ipairs(keypad) do
  bind(mod .. " + code:" .. code,         hl.dsp.focus({ workspace = i }),          "Workspace: go to " .. i .. " (keypad)")
  bind(mod .. " + SHIFT + code:" .. code, hl.dsp.window.move({ workspace = i }),    "Workspace: send window to " .. i .. " (keypad)")
end
bind(mod .. " + CTRL + left",            hl.dsp.focus({ workspace = "e-1" }),      "Workspace: previous")
bind(mod .. " + CTRL + right",           hl.dsp.focus({ workspace = "e+1" }),      "Workspace: next")
bind(mod .. " + mouse_down",             hl.dsp.focus({ workspace = "e+1" }),      "Workspace: next (scroll)")
bind(mod .. " + mouse_up",               hl.dsp.focus({ workspace = "e-1" }),      "Workspace: previous (scroll)")
bind(mod .. " + grave",                  hl.dsp.workspace.toggle_special("scratch"), "Scratchpad: toggle")
bind(mod .. " + SHIFT + grave",          hl.dsp.window.move({ workspace = "special:scratch" }), "Scratchpad: send window")

bind(mod .. " + R", hl.dsp.submap("resize"), "Resize: enter resize mode (esc / return to leave)")
hl.define_submap("resize", function()
  local step = 40
  local keys = {
    { "h", -step, 0 }, { "l", step, 0 }, { "k", 0, -step }, { "j", 0, step },
    { "left", -step, 0 }, { "right", step, 0 }, { "up", 0, -step }, { "down", 0, step },
  }
  for _, k in ipairs(keys) do
    bind(k[1], hl.dsp.window.resize({ x = k[2], y = k[3], relative = true }), "Resize mode: " .. k[1], { repeating = true })
  end
  bind("escape", hl.dsp.submap("reset"), "Resize mode: leave")
  bind("Return", hl.dsp.submap("reset"), "Resize mode: leave")
end)

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, description = "Mouse: move window" })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Mouse: resize window" })

-- volume goes straight to pipewire so it works with the shell down
local lr = { locked = true, repeating = true }
bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), "Media: volume up",   lr)
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      "Media: volume down", lr)
bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     "Media: mute",        lr)
bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   "Media: mic mute",    lr)
bind("XF86MonBrightnessUp",   shell("brightness-up"),   "Media: brightness up",   lr)
bind("XF86MonBrightnessDown", shell("brightness-down"), "Media: brightness down", lr)
bind("XF86AudioPlay",  shell("media-play"), "Media: play / pause", { locked = true })
bind("XF86AudioPause", shell("media-play"), "Media: play / pause (pause key)", { locked = true })
bind("XF86AudioNext",  shell("media-next"), "Media: next track",     { locked = true })
bind("XF86AudioPrev",  shell("media-prev"), "Media: previous track", { locked = true })

-- awkward on purpose. the way out when the shell is broken
bind(mod .. " + CTRL + SHIFT + Q", hl.dsp.exit(), "Session: emergency logout (works without the shell)")
