local S = require("modules.settings")

hl.config({
  input = {
    kb_layout = S.kb_layout,
    kb_variant = S.kb_variant,
    kb_options = S.kb_options,
    numlock_by_default = true,
    repeat_rate = 35,
    repeat_delay = 250,

    follow_mouse = 1,
    sensitivity = 0,
    accel_profile = "flat",

    touchpad = {
      natural_scroll = true,
      disable_while_typing = true,
    },
  },
})
