-- libLassebq dofiles every loadlist script again on each hooked event.
-- Always return the same table. Bootstrap's later loads return {}, so this
-- file is the one that keeps the presence hooks installed.

-- KZM_seal_hooks (kzm/bootstrap.lua) keeps libLassebq from leaking a Lua stack slot
-- on every event this table does not hook.
local seal = rawget(_G, "KZM_seal_hooks") or function(hooks)
  return hooks or {}
end
if _G.__KZM_DISCORD_HOOKS then
  return seal(_G.__KZM_DISCORD_HOOKS)
end

local function mod_root()
  local ok, data = pcall(function()
    return assert(loadfile("kzm/__kzm_mods.lua"))()
  end)
  if ok and type(data) == "table" and type(data.mods) == "table" then
    for _, mod in ipairs(data.mods) do
      if mod.id == "kzm-discord" and type(mod.root) == "string" and mod.root ~= "" then
        return mod.root:gsub("\\", "/")
      end
    end
  end
  return "mods/kzm-discord/0.1.0"
end

local root = mod_root()
package.path = root .. "/lua/?.lua;" .. package.path

local Presence = require("presence")

local OBJECTS = {
  "obj_global_controller",
  "obj_master",
  "obj_titlemenu",
  "obj_gametitle_splash",
  "obj_pausemenu",
  "obj_gamepaused",
  "obj_player",
  "obj_speedrun_master",
  "obj_musicmaster",
}

local function note(message)
  local handle = io.open("mods/kzm-discord/discover.log", "a")
  if not handle then
    return
  end
  handle:write(tostring(message), "\n")
  handle:close()
end

local hooks = {}
for _, object_name in ipairs(OBJECTS) do
  local name = object_name
  hooks[name] = {
    Step = function(_parent, self)
      Presence.observe(name, self)
      local ok, err = pcall(Presence.poll)
      if not ok and not _G.__KZM_DISCORD_POLL_LOGGED then
        _G.__KZM_DISCORD_POLL_LOGGED = true
        note("poll error: " .. tostring(err))
      end
    end,
  }
end

_G.__KZM_DISCORD_HOOKS = hooks
note("hooks ready")
return seal(hooks)
