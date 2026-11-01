--- Resolve GameMaker names exposed by libLassebq, with or without a GML_ prefix.
local function resolve(name)
  return _G[name] or _G["GML_" .. name]
end

local function field(object, key)
  if object == nil or key == nil then
    return nil
  end
  if type(object) ~= "table" and type(object) ~= "userdata" then
    return nil
  end
  local ok, value = pcall(function()
    return object[key]
  end)
  if ok then
    return value
  end
  return nil
end

local function truthy(value)
  return value == true or value == 1
end

return {
  resolve = resolve,
  field = field,
  truthy = truthy,
}
