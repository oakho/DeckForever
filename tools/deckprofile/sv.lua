-- Load and write WoW SavedVariables files (plain Lua assignments of globals).
local M = {}

function M.load(path)
  local env = {}
  local chunk = assert(loadfile(path, "t", env))
  chunk()
  local order = {}
  for line in io.lines(path) do
    local name = line:match("^([%a_][%w_]*) = ")
    if name then order[#order + 1] = name end
  end
  return env, order
end

local function key(k)
  if type(k) == "string" then return string.format("[%q]", k) end
  if math.type(k) == "integer" then return "[" .. k .. "]" end
  return "[" .. string.format("%.17g", k) .. "]"
end

local function value(v, out, ind)
  local t = type(v)
  if t == "string" then out[#out + 1] = string.format("%q", v):gsub("\\\n", "\\n")
  elseif t == "number" then
    if math.type(v) == "integer" then out[#out + 1] = tostring(v)
    elseif v ~= v then out[#out + 1] = "0/0"
    elseif v == math.huge then out[#out + 1] = "math.huge"
    elseif v == -math.huge then out[#out + 1] = "-math.huge"
    else out[#out + 1] = string.format("%.17g", v) end
  elseif t == "boolean" then out[#out + 1] = tostring(v)
  elseif t == "table" then
    out[#out + 1] = "{\n"
    local ks = {}
    for k in pairs(v) do ks[#ks + 1] = k end
    table.sort(ks, function(a, b)
      local ta, tb = type(a), type(b)
      if ta ~= tb then return ta < tb end
      return a < b
    end)
    for _, k in ipairs(ks) do
      out[#out + 1] = key(k) .. " = "
      value(v[k], out, ind)
      out[#out + 1] = ",\n"
    end
    out[#out + 1] = "}"
  else out[#out + 1] = "nil" end
end

function M.save(path, env, order)
  local out = {}
  local seen = {}
  for _, name in ipairs(order) do
    if env[name] ~= nil and not seen[name] then
      seen[name] = true
      out[#out + 1] = "\n" .. name .. " = "
      value(env[name], out)
      out[#out + 1] = "\n"
    end
  end
  local f = assert(io.open(path, "w"))
  f:write(table.concat(out))
  f:close()
end

function M.copy(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = M.copy(v) end
  return c
end

return M
