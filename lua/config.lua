local ROOT = "mods/kzm-discord/"

local function parse(body)
  local cfg = {
    application_id = "",
    language = "auto",
    privacy = "chapter",
    show_elapsed = true,
  }
  if type(body) ~= "string" then
    return cfg
  end
  for line in body:gmatch("[^\r\n]+") do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed ~= "" and trimmed:sub(1, 1) ~= "#" and trimmed:sub(1, 1) ~= "[" then
      local key, value = trimmed:match("^([%w_]+)%s*=%s*(.+)$")
      if key and value then
        local quoted = value:match('^"(.*)"$')
        if quoted ~= nil then
          value = quoted
        end
        if value == "true" then
          value = true
        elseif value == "false" then
          value = false
        end
        cfg[key] = value
      end
    end
  end
  if cfg.language ~= "auto" and cfg.language ~= "ru" and cfg.language ~= "en" then
    cfg.language = "auto"
  end
  if cfg.privacy ~= "vague" then
    cfg.privacy = "chapter"
  end
  cfg.show_elapsed = cfg.show_elapsed ~= false
  if type(cfg.application_id) ~= "string" then
    cfg.application_id = tostring(cfg.application_id or "")
  end
  return cfg
end

local function read_file(path)
  local handle = io.open(path, "r")
  if not handle then
    return nil
  end
  local body = handle:read("*a")
  handle:close()
  return body
end

local function ensure_user_file()
  local path = ROOT .. "discord.toml"
  if read_file(path) then
    return path
  end
  local defaults = read_file(ROOT .. "discord.default.toml")
  if not defaults then
    return path
  end
  local handle = io.open(path, "w")
  if handle then
    handle:write(defaults)
    handle:close()
  end
  return path
end

local function load()
  local path = ensure_user_file()
  return parse(read_file(path))
end

return {
  root = ROOT,
  load = load,
  parse = parse,
}
