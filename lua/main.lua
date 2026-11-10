local Mod = require("kzm.sdk.mod")
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

return Mod.define({
  id = "kzm-discord",

  onLoad = function(ctx)
    Presence.init(ctx)
    ctx.log("discord presence ready")
  end,

  hooks = function()
    local objects = {}
    for _, name in ipairs(OBJECTS) do
      objects[name] = {
        Step = function(_parent, self)
          Presence.observe(name, self)
          Presence.poll()
        end,
      }
    end
    return {
      scripts = {},
      objects = objects,
    }
  end,
})
