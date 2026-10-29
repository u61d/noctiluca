local T = require("tokens")
local S = require("modules.settings")

hl.config({
  general = {
    gaps_in = T.spacing.s2,          -- 4  (8 px between windows)
    gaps_out = T.spacing.s3,         -- 8
    border_size = 1,
    layout = "dwindle",
    resize_on_border = true,
    allow_tearing = false,
  },

  dwindle = {
    preserve_split = true,
  },

  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    force_default_wallpaper = 0,           -- the shell draws the wallpaper
    vrr = S.vrr,
    mouse_move_enables_dpms = true,
    key_press_enables_dpms = true,
    animate_manual_resizes = true,
    -- lets a restarted shell take the lock back if it crashed while locked
    allow_session_lock_restore = true,
  },

  cursor = {
    inactive_timeout = 4,                  -- hide the pointer after 4 s of inactivity
    hide_on_key_press = true,
  },

  binds = {
    workspace_back_and_forth = true,
  },

  ecosystem = {
    no_update_news = true,
    no_donation_nag = true,
  },
})
