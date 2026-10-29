require("modules.settings")
require("modules.env")
require("modules.monitors")
require("modules.curves")
require("modules.animations")

local theme = require("modules.theme")
if type(theme.apply) == "function" then theme.apply() end

require("modules.general")
require("modules.decoration")
require("modules.input")
require("modules.gestures")
require("modules.keybinds")
require("modules.rules")
require("modules.autostart")
require("modules.user")          -- last, so it wins
