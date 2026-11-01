local TEST = {
  test = true,
  room33 = true,
  room68 = true,
  room69 = true,
  CLUB2OLD = true,
  room_folder = true,
  room_tiletest = true,
  room_sfx_test = true,
  room_finale_test = true,
  room_test_dialogue = true,
  room_test_lighting = true,
  room_multiplayer_setup = true,
  room_multiplayer_test = true,
}

local MENU = {
  room_title = true,
  room_logo = true,
  room_optionsprompt = true,
  room_saveprompt = true,
}

local LEVEL = {
  room_level_select = true,
  room_stage_results = true,
  room_speedrun_results = true,
}

local LOADING = {
  room_init = true,
  room_empty = true,
  room_loadfail = true,
}

local PREFIXES = {
  { "room_prison_sewer", "sewer" },
  { "room_apartment", "apartment" },
  { "room_neighbor", "apartment" },
  { "room_apt_", "apartment" },
  { "room_hallway", "apartment" },
  { "room_oldmotel", "hotel" },
  { "room_factory", "factory" },
  { "room_motel", "hotel" },
  { "room_club", "club" },
  { "room_prison", "prison" },
  { "room_chinatown", "chinatown" },
  { "room_dragon", "studio" },
  { "room_oldmansion", "mansion" },
  { "room_mansion", "mansion" },
  { "room_bunker", "bunker" },
  { "room_government", "lab" },
  { "room_pre_cathedral", "cathedral" },
  { "room_cathedral", "cathedral" },
  { "room_psychiatrist", "psychiatrist" },
  { "room_nightmare", "dream" },
  { "room_tiedup", "dream" },
  { "room_cutscene", "cutscene" },
  { "room_videostore", "videostore" },
  { "room_rooftop", "rooftop" },
  { "room_limo", "limo" },
  { "room_sewer", "sewer" },
  { "room_bar", "bar" },
}

local function starts_with(text, prefix)
  return text:sub(1, #prefix) == prefix
end

--- Returns "test", or a stable place key such as "menu" or "factory".
local function classify(room_name)
  if type(room_name) ~= "string" or room_name == "" then
    return "loading"
  end
  if TEST[room_name] then
    return "test"
  end
  if MENU[room_name] or starts_with(room_name, "room_splash") then
    return "menu"
  end
  if LEVEL[room_name] then
    return "level_select"
  end
  if LOADING[room_name] then
    return "loading"
  end
  if starts_with(room_name, "room_ending") or room_name == "room_postcredits" then
    return "ending"
  end
  if starts_with(room_name, "room_haunted") then
    return "secret"
  end
  for _, item in ipairs(PREFIXES) do
    if starts_with(room_name, item[1]) then
      return item[2]
    end
  end
  return "unknown"
end

return {
  classify = classify,
}
