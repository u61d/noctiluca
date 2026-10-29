-- runs a hyprland lua config against a strict mock of `hl`.
--   lua tests/hl_harness.lua CONFIG_DIR [--stubs FILE] [--keybinds-md FILE] [--quiet] [--strict] [--greeter]
-- catches unknown keys, bad types, dispatcher args, bind options hyprland would silently
-- ignore, missing submaps and the shell contract. it can't prove hyprland accepts the
-- config, `Hyprland --verify-config` has the final word.

local here = (debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) or "."
local C = dofile(here .. "/hl_constants.lua")

local config_dir, stubs_path, keybinds_md, quiet, strict, greeter
do
  local i = 1
  while i <= #arg do
    local a = arg[i]
    if a == "--stubs" then stubs_path = arg[i + 1]; i = i + 1
    elseif a == "--keybinds-md" then keybinds_md = arg[i + 1]; i = i + 1
    elseif a == "--quiet" then quiet = true
    elseif a == "--strict" then strict = true
    elseif a == "--greeter" then greeter = true
    elseif not config_dir then config_dir = a end
    i = i + 1
  end
end
assert(config_dir, "usage: lua hl_harness.lua CONFIG_DIR [--stubs FILE] [--keybinds-md FILE] [--quiet]")
config_dir = config_dir:gsub("/+$", "")

local errors, warnings, stats = {}, {}, { binds = 0, rules = 0, animations = 0, config_values = 0, curves = 0, exec = 0 }

local function where()
  for level = 2, 14 do
    local info = debug.getinfo(level, "Sl")
    if not info then break end
    if info.source:sub(1, 1) == "@" and info.source:find(config_dir, 1, true) then
      return info.source:sub(2 + #config_dir + 1) .. ":" .. info.currentline
    end
  end
  return "?"
end

local function err(fmt, ...) errors[#errors + 1] = where() .. ": " .. string.format(fmt, ...) end
local function warn(fmt, ...) warnings[#warnings + 1] = where() .. ": " .. string.format(fmt, ...) end

local function lev(a, b)
  local m, n = #a, #b
  local d = {}
  for i = 0, m do d[i] = { [0] = i } end
  for j = 0, n do d[0][j] = j end
  for i = 1, m do
    for j = 1, n do
      local cost = a:sub(i, i) == b:sub(j, j) and 0 or 1
      d[i][j] = math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
    end
  end
  return d[m][n]
end

local function suggest(key, universe)
  local best, bd = nil, 4
  for k in pairs(universe) do
    local d = lev(key, k)
    if d < bd then best, bd = k, d end
  end
  return best and (" (did you mean '" .. best .. "'?)") or ""
end

local stub = { classes = {}, events = {}, api = {} }
if stubs_path then
  local f = io.open(stubs_path, "r")
  if f then
    local cur, in_events = nil, false
    for line in f:lines() do
      local c = line:match("^%-%-%-@class ([%w%._]+)")
      if c then cur = {}; stub.classes[c] = cur; in_events = false
      elseif line:match("^%-%-%-@alias HL%.EventName") then in_events = true; cur = nil
      elseif in_events and line:match("^%-%-%-|") then
        local ev = line:match('"([%w_%.]+)"')
        if ev then stub.events[ev] = true end
      else
        in_events = false
        local n, t = line:match("^%-%-%-@field ([%w_]+)%??%s+(.-)%s*$")
        if n and cur then cur[n] = t end
      end
    end
    f:close()
    for n in pairs(stub.classes["HL.API"] or {}) do stub.api[n] = true end
  else
    warnings[#warnings + 1] = "stubs file not readable: " .. stubs_path
  end
else
  warnings[#warnings + 1] = "no --stubs given: event names and spec fields are not checked"
end

local function valid_color(v)
  if math.type(v) == "integer" then return true end
  if type(v) ~= "string" then return false end
  return v:match("^rgba%(%x%x%x%x%x%x%x%x%)$") or v:match("^rgb%(%x%x%x%x%x%x%)$")
      or v:match("^0x%x+$") or v:match("^#%x%x%x%x%x%x%x?%x?$") or false
end

local function check_value(key, v, spec)
  local t = spec.type
  local ok, why = true, nil
  if t == "Bool" then
    ok = type(v) == "boolean"
  elseif t == "Int" then
    if spec.map and type(v) == "string" then
      local found = false
      for _, m in ipairs(spec.map) do if m == v then found = true end end
      ok, why = found, "one of " .. table.concat(spec.map, "/")
    else
      ok = math.type(v) == "integer"
      if not ok and type(v) == "number" then why = "integer (got float " .. v .. ")" end
    end
  elseif t == "Float" then
    ok = type(v) == "number"
  elseif t == "String" then
    ok = type(v) == "string"
    if ok and spec.choices then
      local found = false
      for _, c in ipairs(spec.choices) do if c == v then found = true end end
      if not found and v ~= "" then ok, why = false, "one of " .. table.concat(spec.choices, "/") end
    end
  elseif t == "Gradient" then
    ok = valid_color(v) or (type(v) == "table" and type(v.colors) == "table")
    why = "colour like \"rgba(rrggbbaa)\" or { colors = {...}, angle = n }"
  elseif t == "Color" then
    ok, why = valid_color(v), "colour like \"rgba(rrggbbaa)\""
  elseif t == "Vec2" then
    ok = type(v) == "string" or (type(v) == "table" and #v == 2)
  elseif t == "CssGap" then
    ok = type(v) == "string" or type(v) == "number" or type(v) == "table"
  end
  if not ok then
    err("config '%s': expected %s%s, got %s %s", key, t, why and (" [" .. why .. "]") or "", type(v), tostring(v))
    return
  end
  if (t == "Int" or t == "Float") and type(v) == "number" then
    if spec.min and v < spec.min then err("config '%s' = %s is below the minimum %s", key, v, spec.min) end
    if spec.max and v > spec.max then err("config '%s' = %s is above the maximum %s", key, v, spec.max) end
  end
end

local function flatten(t, prefix, out)
  for k, v in pairs(t) do
    local key = prefix and (prefix .. "." .. k) or tostring(k)
    local spec = C.config[key]
    if spec then
      out[#out + 1] = { key, v, spec }
    elseif type(v) == "table" then
      flatten(v, key, out)
    else
      local parent = key:match("^(.*)%.[^.]+$") or ""
      local siblings = {}
      for ck in pairs(C.config) do
        local p, leaf = ck:match("^(.*)%.([^.]+)$")
        if p == parent then siblings[leaf] = true end
      end
      err("unknown config option '%s'%s", key, suggest(key:match("[^.]+$"), siblings))
    end
  end
end

local handlers, submaps_defined, submaps_used = {}, {}, {}
local curves, execs, binds = {}, {}, {}
local current_submap = nil
local layer_rules, shortcuts_bound = {}, {}

local function is_style_ok(leaf, style)
  if style == nil or style == "" then return true end
  local function pct(s) return s:match("^%S+ %d+%%$") or not s:find(" ") end
  if leaf:match("^windows") then return style:match("^slide") or style == "gnome" or style == "gnomed" or style:match("^popin") ~= nil and pct(style) end
  if leaf:match("^workspaces") or leaf:match("^specialWorkspace") then return (style:match("^slide") or style == "fade") and pct(style) end
  if leaf:match("angle$") then return style == "loop" or style == "once" end
  if leaf:match("^layers") then return style == "fade" or style:match("^slide") or (style:match("^popin") and pct(style)) end
  return false -- fade* leaves and others take no style
end

local hl = {}

function hl.config(tbl)
  if type(tbl) ~= "table" then return err("hl.config expects a table") end
  local flat = {}
  flatten(tbl, nil, flat)
  for _, e in ipairs(flat) do check_value(e[1], e[2], e[3]); stats.config_values = stats.config_values + 1 end
end

function hl.env(name, value, dbus)
  if type(name) ~= "string" or name == "" then err("hl.env: name must be a non-empty string") end
  if type(value) ~= "string" then err("hl.env('%s'): value must be a string, got %s", tostring(name), type(value)) end
  if dbus ~= nil and type(dbus) ~= "boolean" then err("hl.env('%s'): third argument must be boolean", tostring(name)) end
end

function hl.curve(name, spec)
  stats.curves = stats.curves + 1
  if type(name) ~= "string" or type(spec) ~= "table" then return err("hl.curve(name, spec) expects a string and a table") end
  if spec.type == "bezier" then
    local p = spec.points
    if type(p) ~= "table" or #p ~= 2 then return err("hl.curve('%s'): bezier needs points = { {x1,y1}, {x2,y2} }", name) end
    for _, pt in ipairs(p) do
      for _, c in ipairs(pt) do
        if type(c) ~= "number" or c < -1 or c > 2 then err("hl.curve('%s'): bezier coordinate %s is outside [-1, 2]", name, tostring(c)) end
      end
    end
  elseif spec.type == "spring" then
    if spec.damping ~= nil then err("hl.curve('%s'): `damping` is not read by Hyprland v%s (key is `dampening`)", name, C.version) end
    for _, k in ipairs({ "mass", "stiffness", "dampening" }) do
      if type(spec[k]) ~= "number" or spec[k] <= 0.5 then err("hl.curve('%s'): spring %s must be a number > 0.5", name, k) end
    end
  else
    return err("hl.curve('%s'): type must be 'bezier' or 'spring'", name)
  end
  curves[name] = spec.type
end

function hl.animation(spec)
  stats.animations = stats.animations + 1
  if type(spec) ~= "table" then return err("hl.animation expects a table") end
  local leaf_ok = false
  for _, l in ipairs(C.animation_leaves) do if l == spec.leaf then leaf_ok = true end end
  if not leaf_ok then
    local u = {}
    for _, l in ipairs(C.animation_leaves) do u[l] = true end
    return err("hl.animation: unknown leaf '%s'%s", tostring(spec.leaf), suggest(tostring(spec.leaf), u))
  end
  if spec.curve ~= nil then err("hl.animation('%s'): `curve =` is not accepted (use bezier = or spring =)", spec.leaf) end
  for k in pairs(spec) do
    if not ({ leaf = 1, enabled = 1, speed = 1, bezier = 1, spring = 1, style = 1, curve = 1 })[k] then
      err("hl.animation('%s'): unknown field '%s'", spec.leaf, tostring(k))
    end
  end
  if spec.enabled == false then return end
  if type(spec.speed) ~= "number" or spec.speed <= 0 or spec.speed > 100 then
    err("hl.animation('%s'): speed must be in (0, 100] (deciseconds), got %s", spec.leaf, tostring(spec.speed))
  end
  if (spec.bezier == nil) == (spec.spring == nil) then
    err("hl.animation('%s'): exactly one of bezier / spring is required", spec.leaf)
  else
    local name, kind = spec.bezier or spec.spring, spec.bezier and "bezier" or "spring"
    if curves[name] == nil then err("hl.animation('%s'): curve '%s' is not defined (define it with hl.curve first)", spec.leaf, name)
    elseif curves[name] ~= kind then err("hl.animation('%s'): '%s' is a %s curve but was given as %s =", spec.leaf, name, curves[name], kind) end
  end
  if not is_style_ok(spec.leaf, spec.style) then
    err("hl.animation('%s'): style '%s' is not valid for this leaf", spec.leaf, tostring(spec.style))
  end
end

function hl.monitor(spec)
  local cls = stub.classes["HL.MonitorSpec"]
  if type(spec) ~= "table" then return err("hl.monitor expects a table") end
  if type(spec.output) ~= "string" then err("hl.monitor: `output` (string) is required; use \"\" for any") end
  if cls then
    for k in pairs(spec) do if not cls[k] then err("hl.monitor: unknown field '%s'%s", k, suggest(k, cls)) end end
  end
end

local MODS = { SHIFT = 1, CAPS = 1, CTRL = 1, CONTROL = 1, ALT = 1, MOD2 = 1, MOD3 = 1, SUPER = 1, WIN = 1, LOGO = 1, MOD4 = 1, MOD5 = 1, META = 1 }

local function new_dsp(name, args) return { __dsp = name, args = args } end

function hl.bind(keys, dispatcher, opts)
  stats.binds = stats.binds + 1
  if type(keys) ~= "string" then return err("hl.bind: keys must be a string") end
  -- lua function binds are "__lua" to hyprland: run them once against a recording hl.dispatch
  if type(dispatcher) == "function" then
    local sent = {}
    local saved = hl.dispatch
    hl.dispatch = function(d) sent[#sent + 1] = d end
    local ok, e = pcall(dispatcher)
    hl.dispatch = saved
    if not ok then return err("hl.bind('%s'): its function failed: %s", keys, tostring(e)) end
    if #sent == 0 then return err("hl.bind('%s'): its function dispatches nothing", keys) end
    for _, d in ipairs(sent) do
      if type(d) ~= "table" or not d.__dsp then return err("hl.bind('%s'): its function dispatches something that isn't an hl.dsp.* dispatcher", keys) end
      if d.__dsp == "global" then shortcuts_bound[d.args[1]] = true end
    end
    dispatcher = { __dsp = "__lua", args = {} }
  end
  if type(dispatcher) ~= "table" or not dispatcher.__dsp then return err("hl.bind('%s'): second argument must be an hl.dsp.* dispatcher", keys) end
  local parts = {}
  for p in keys:gmatch("[^%+]+") do parts[#parts + 1] = p:match("^%s*(.-)%s*$") end
  local key = table.remove(parts)
  if not key or key == "" then return err("hl.bind('%s'): no key", keys) end
  for _, m in ipairs(parts) do
    if not MODS[m] then err("hl.bind('%s'): unknown modifier '%s'", keys, m) end
  end
  opts = opts or {}
  local known = {}
  for _, o in ipairs(C.bind_options) do known[o] = true end
  for k in pairs(opts) do
    if not known[k] then err("hl.bind('%s'): unknown option '%s' (Hyprland would silently ignore it)%s", keys, k, suggest(k, known)) end
  end
  table.sort(parts)
  local id = (current_submap or "") .. "|" .. table.concat(parts, "+") .. "+" .. key:lower()
  for _, b in ipairs(binds) do
    if b.id == id then err("hl.bind('%s'): duplicate of an earlier bind (%s)", keys, b.desc or "?") end
  end
  binds[#binds + 1] = { id = id, mods = parts, key = key, dsp = dispatcher, desc = opts.description or opts.desc, submap = current_submap }
  if dispatcher.__dsp == "global" then shortcuts_bound[dispatcher.args[1]] = true end
  return { set_enabled = function() end, remove = function() end }
end

function hl.unbind() end
function hl.dispatch(d) end

function hl.define_submap(name, a, b)
  local fn = type(a) == "function" and a or b
  if type(name) ~= "string" or type(fn) ~= "function" then return err("hl.define_submap(name, [reset], fn)") end
  if type(a) == "string" then warn("hl.define_submap('%s'): reset = '%s' makes the mode one-shot (any bind returns to it)", name, a) end
  submaps_defined[name] = 0
  local before = #binds
  current_submap = name
  fn()
  current_submap = nil
  submaps_defined[name] = #binds - before
  if #binds == before then err("hl.define_submap('%s'): no binds defined inside", name) end
end

function hl.on(event, fn)
  if type(fn) ~= "function" then return err("hl.on('%s'): handler must be a function", tostring(event)) end
  if next(stub.events) and not stub.events[event] then
    return err("hl.on: unknown event '%s'%s", tostring(event), suggest(tostring(event), stub.events))
  end
  handlers[event] = handlers[event] or {}
  table.insert(handlers[event], fn)
end

function hl.exec_cmd(cmd)
  stats.exec = stats.exec + 1
  if type(cmd) ~= "string" or cmd == "" then return err("hl.exec_cmd: command must be a non-empty string") end
  execs[#execs + 1] = cmd
end

local function spec_keys(cls_name, fname, spec)
  local cls = stub.classes[cls_name]
  if type(spec) ~= "table" then return err("%s expects a table", fname) end
  if cls then
    for k in pairs(spec) do if not cls[k] then err("%s: unknown field '%s'%s", fname, tostring(k), suggest(tostring(k), cls)) end end
  end
end
function hl.gesture(spec) spec_keys("HL.GestureSpec", "hl.gesture", spec) end
function hl.device(spec) spec_keys("HL.DeviceSpec", "hl.device", spec) end
function hl.workspace_rule(spec) spec_keys("HL.WorkspaceRuleSpec", "hl.workspace_rule", spec); stats.rules = stats.rules + 1 end
function hl.permission() end
function hl.timer() return { set_enabled = function() end } end
function hl.version() return C.version end

local function check_match(fname, match, allowed)
  if match == nil then return end
  if type(match) ~= "table" then return err("%s: match must be a table", fname) end
  local ok = {}
  for _, k in ipairs(allowed) do ok[k] = true end
  for k, v in pairs(match) do
    if not ok[k] then err("%s: unknown match key '%s'%s", fname, tostring(k), suggest(tostring(k), ok)) end
    if type(v) ~= "string" and type(v) ~= "boolean" then err("%s: match.%s must be a string or boolean", fname, tostring(k)) end
  end
end

function hl.window_rule(spec)
  stats.rules = stats.rules + 1
  if type(spec) ~= "table" then return err("hl.window_rule expects a table") end
  check_match("hl.window_rule", spec.match, C.window_match_keys)
  for k, v in pairs(spec) do
    if k ~= "name" and k ~= "enabled" and k ~= "match" then
      local t = C.window_effects[k]
      if not t then err("hl.window_rule('%s'): unknown effect '%s'%s", tostring(spec.name), k, suggest(k, C.window_effects))
      elseif t == "Bool" and type(v) ~= "boolean" then err("hl.window_rule: effect '%s' expects a boolean", k)
      elseif t == "String" and type(v) ~= "string" then err("hl.window_rule: effect '%s' expects a string", k)
      elseif t == "Int" and math.type(v) ~= "integer" then err("hl.window_rule: effect '%s' expects an integer", k)
      elseif t == "Float" and type(v) ~= "number" then err("hl.window_rule: effect '%s' expects a number", k) end
    end
  end
end

function hl.layer_rule(spec)
  stats.rules = stats.rules + 1
  if type(spec) ~= "table" then return err("hl.layer_rule expects a table") end
  check_match("hl.layer_rule", spec.match, C.layer_match_keys)
  for k, v in pairs(spec) do
    if k ~= "name" and k ~= "enabled" and k ~= "match" then
      local t = C.layer_effects[k]
      if not t then err("hl.layer_rule('%s'): unknown effect '%s'%s", tostring(spec.name), k, suggest(k, C.layer_effects))
      elseif t == "bool" and type(v) ~= "boolean" then err("hl.layer_rule: effect '%s' expects a boolean", k)
      elseif t == "float01" and (type(v) ~= "number" or v < 0 or v > 1) then err("hl.layer_rule: '%s' must be a number in [0, 1]", k)
      elseif t == "int02" and (math.type(v) ~= "integer" or v < 0 or v > 2) then err("hl.layer_rule: '%s' must be an integer 0..2", k)
      elseif t == "int" and math.type(v) ~= "integer" then err("hl.layer_rule: '%s' must be an integer", k)
      elseif t == "string" and type(v) ~= "string" then err("hl.layer_rule: '%s' must be a string", k) end
    end
  end
  if spec.animation and not is_style_ok("layers", spec.animation) then err("hl.layer_rule: animation '%s' is not a valid layer style", spec.animation) end
  layer_rules[#layer_rules + 1] = spec
end

local function one_of(v, set) for _, s in ipairs(set) do if v == s then return true end end return false end
local DIRS = { "left", "right", "up", "down" }
local VALID = {
  exec_cmd = function(a) if type(a[1]) ~= "string" or a[1] == "" then err("hl.dsp.exec_cmd expects a non-empty string") end end,
  global = function(a) if type(a[1]) ~= "string" or not a[1]:match("^[%w_%-]+:[%w_%-%.]+$") then err("hl.dsp.global expects \"appid:name\", got %s", tostring(a[1])) end end,
  submap = function(a)
    if type(a[1]) ~= "string" then return err("hl.dsp.submap expects a string") end
    if a[1] ~= "reset" then submaps_used[a[1]] = where() end
  end,
  layout = function(a) if type(a[1]) ~= "string" then err("hl.dsp.layout expects a string") end end,
  dpms = function(a)
    local t = a[1]
    if t ~= nil and (type(t) ~= "table" or not one_of(t.action, { "on", "off", "enable", "disable", "toggle" })) then err("hl.dsp.dpms: action must be on/off/toggle") end
  end,
  focus = function(a)
    local t = a[1]
    if type(t) ~= "table" then return err("hl.dsp.focus expects a table") end
    local n = 0
    for k, v in pairs(t) do
      n = n + 1
      if not one_of(k, { "direction", "monitor", "workspace", "window", "urgent_or_last", "last" }) then err("hl.dsp.focus: unknown field '%s'", tostring(k)) end
      if k == "direction" and not one_of(v, DIRS) then err("hl.dsp.focus: direction must be left/right/up/down") end
    end
    if n ~= 1 then err("hl.dsp.focus: exactly one field is expected") end
  end,
  ["window.move"] = function(a)
    local t = a[1]
    if type(t) ~= "table" then return err("hl.dsp.window.move expects a table") end
    local ok = t.direction or t.workspace or t.monitor or (t.x and t.y)
    if not ok then err("hl.dsp.window.move: needs direction, workspace, monitor or x+y") end
    if t.direction and not one_of(t.direction, DIRS) then err("hl.dsp.window.move: direction must be left/right/up/down") end
  end,
  ["window.resize"] = function(a)
    local t = a[1]
    if t ~= nil and (type(t) ~= "table" or type(t.x) ~= "number" or type(t.y) ~= "number") then err("hl.dsp.window.resize: needs { x = n, y = n [, relative = bool] } or no argument (mouse)") end
  end,
  ["window.fullscreen"] = function(a)
    local t = a[1] or {}
    if t.mode and not one_of(t.mode, { "fullscreen", "maximized" }) then err("hl.dsp.window.fullscreen: mode must be fullscreen/maximized") end
    if t.action and not one_of(t.action, { "toggle", "set", "unset" }) then err("hl.dsp.window.fullscreen: action must be toggle/set/unset") end
  end,
  ["window.float"] = function(a)
    local t = a[1]
    if t ~= nil and (type(t) ~= "table" or not one_of(t.action, { "toggle", "enable", "disable", "on", "off" })) then err("hl.dsp.window.float: action must be toggle/enable/disable") end
  end,
  ["workspace.toggle_special"] = function(a) if type(a[1]) ~= "string" then err("hl.dsp.workspace.toggle_special expects a string") end end,
}

local dsp = {}
local function make_ns(ns, names)
  local t = ns and {} or dsp
  for _, name in ipairs(names) do
    local full = ns and (ns .. "." .. name) or name
    t[name] = function(...)
      local a = { ... }
      if VALID[full] then VALID[full](a) end
      return new_dsp(name, a)
    end
  end
  if ns then
    dsp[ns] = setmetatable(t, { __index = function(_, k) err("hl.dsp.%s.%s does not exist in Hyprland v%s", ns, tostring(k), C.version) end })
  end
end
for ns, names in pairs(C.dsp) do make_ns(ns ~= "_root" and ns or nil, names) end
hl.dsp = setmetatable(dsp, { __index = function(_, k) err("hl.dsp.%s does not exist in Hyprland v%s", tostring(k), C.version) end })

setmetatable(hl, { __index = function(_, k)
  if stub.api[k] then return function() end end
  err("hl.%s does not exist in the API of Hyprland v%s", tostring(k), C.version)
  return function() end
end })

_G.hl = hl

package.path = config_dir .. "/?.lua;" .. config_dir .. "/?/init.lua;" .. package.path
local function run(label, fn)
  local ok, e = xpcall(fn, debug.traceback)
  if not ok then errors[#errors + 1] = label .. " raised a Lua error:\n" .. tostring(e) end
  return ok
end

local loaded = run("hyprland.lua", function() dofile(config_dir .. "/hyprland.lua") end)

if loaded and greeter then
  for _, fn in ipairs(handlers["hyprland.start"] or {}) do run("hyprland.start handler", fn) end
  local started = false
  for _, c in ipairs(execs) do if c:find("quickshell %-p") and c:find("hl%.dsp%.exit") then started = true end end
  if not started then errors[#errors + 1] = "greeter: hyprland.start must run the greeter and exit after it" end
elseif loaded then
  for _, fn in ipairs(handlers["hyprland.start"] or {}) do run("hyprland.start handler", fn) end
  local started = false
  for _, c in ipairs(execs) do if c:find("noctiluca%-shell") then started = true end end
  if not started then errors[#errors + 1] = "autostart: hyprland.start does not launch noctiluca-shell" end

  -- what noctiluca-theme does live: hyprctl eval '... require("modules.theme").apply()'
  run("live theme reload", function()
    package.loaded["generated.colors"] = nil
    package.loaded["modules.theme"] = nil
    require("modules.theme").apply()
  end)

  for name, loc in pairs(submaps_used) do
    if submaps_defined[name] == nil then errors[#errors + 1] = loc .. ": submap '" .. name .. "' is entered but never defined" end
  end

  run("contract", function()
    local T = require("tokens")
    for _, s in ipairs(T.shell.shortcuts) do
      if not shortcuts_bound[T.shell.appid .. ":" .. s] then errors[#errors + 1] = "contract: shell shortcut '" .. s .. "' is never bound" end
    end
    for _, l in ipairs(T.shell.layers) do
      local ns, found = T.shell.appid .. "-" .. l, false
      for _, r in ipairs(layer_rules) do if r.match and r.match.namespace == "^" .. ns .. "$" then found = true end end
      if not found then errors[#errors + 1] = "contract: shell layer '" .. ns .. "' has no layer rule" end
    end
  end)
end

if keybinds_md then
  local pretty = { SUPER = "Super", SHIFT = "Shift", CTRL = "Ctrl", ALT = "Alt" }
  local function keyname(b)
    local order = { "SUPER", "CTRL", "ALT", "SHIFT" }
    local mods = {}
    for _, o in ipairs(order) do for _, m in ipairs(b.mods) do if m == o then mods[#mods + 1] = pretty[o] end end end
    local k = b.key
    if k == "Super_L" and #mods == 1 and mods[1] == "Super" then return "Super (tap)" end
    -- keypad binds are keycodes (evdev + 8)
    local keypad = { ["79"] = 7, ["80"] = 8, ["81"] = 9, ["83"] = 4, ["84"] = 5, ["85"] = 6,
                     ["87"] = 1, ["88"] = 2, ["89"] = 3, ["90"] = 0 }
    local code = k:match("^code:(%d+)$")
    if code and keypad[code] then k = "Keypad " .. keypad[code] end
    k = k:gsub("^%l", string.upper)
    return table.concat(mods, "+") .. (#mods > 0 and "+" or "") .. k
  end
  local sections, order = {}, {}
  for _, b in ipairs(binds) do
    local sec, text = (b.desc or "Other"):match("^([^:]+):%s*(.*)$")
    sec = sec or "Other"
    text = text or b.desc or ""
    if b.submap then sec = "Mode: " .. b.submap end
    if not sections[sec] then sections[sec] = {}; order[#order + 1] = sec end
    table.insert(sections[sec], { keyname(b), text })
  end
  local f = assert(io.open(keybinds_md, "w"))
  f:write("# Keybinds\n\nGenerated from `config/hypr/modules/keybinds.lua` (`tests/lint.sh --update`), so edit that\ninstead. `Super` is the Windows key.\n\n")
  for _, sec in ipairs(order) do
    f:write("## " .. sec .. "\n\n| Keys | Action |\n|---|---|\n")
    for _, row in ipairs(sections[sec]) do f:write("| `" .. row[1] .. "` | " .. row[2] .. " |\n") end
    f:write("\n")
  end
  f:close()
end

if strict then
  for _, w in ipairs(warnings) do errors[#errors + 1] = "(strict) " .. w end
end
if not quiet then
  print(string.format("config dir : %s", config_dir))
  print(string.format("schema     : Hyprland v%s (%d config options)", C.version, (function() local n = 0 for _ in pairs(C.config) do n = n + 1 end return n end)()))
  print(string.format("executed   : %d config values, %d binds, %d rules, %d animations, %d curves, %d exec_cmd",
    stats.config_values, stats.binds, stats.rules, stats.animations, stats.curves, stats.exec))
  for _, w in ipairs(warnings) do print("  warning: " .. w) end
end
if #errors > 0 then
  print(string.format("RESULT: %d problem(s)", #errors))
  for _, e in ipairs(errors) do print("  - " .. e) end
  os.exit(1)
end
print("RESULT: config executed cleanly against the v" .. C.version .. " schema")
