-- applied last so it wins. delete ~/.local/state/noctiluca/hypr.lua to reset
local S = require("modules.settings")

if type(S.user.config) == "table" then
  hl.config(S.user.config)
end
