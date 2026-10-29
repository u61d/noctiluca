-- 0.56.2: bezier points within [-1, 2], springs above 0.5, and it's `dampening`
local T = require("tokens")

for name, p in pairs(T.curves) do
  hl.curve("noct-" .. name, {
    type = "bezier",
    points = { { p[1], p[2] }, { p[3], p[4] } },
  })
end

for name, s in pairs(T.springs) do
  hl.curve("noct-" .. name, {
    type = "spring",
    mass = s.mass,
    stiffness = s.stiffness,
    dampening = s.dampening,
  })
end
