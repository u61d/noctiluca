local S = require("modules.settings")

hl.on("hyprland.start", function()
  hl.exec_cmd(S.bin_dir .. "/noctiluca-shell")

  -- only for locking before suspend
  hl.exec_cmd("hypridle")

  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)
