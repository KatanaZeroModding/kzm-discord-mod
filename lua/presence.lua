--- Watches the room, track, character and speedrun clock.
--- The speedrun clock is a Discord start timestamp, written again only when
--- the run starts, jumps backward, or leaves pause. A ticking timer does not
--- rewrite presence.json.

local gml = require("gml")
local rooms = require("rooms")
local tracks = require("tracks")
local text = require("text")
local config_mod = require("config")

local Presence = {}

local TIMER_KEYS = {
  "speedrun_timer",
  "speedrun_time",
  "run_timer",
  "run_time",
  "timer_ms",
  "time_ms",
  "igt",
  "elapsed",
  "timer",
  "time",
}

local CHAR_KEYS = {
  "character",
  "char_id",
  "player_character",
  "character_id",
  "skin",
}

local log = function(_msg) end
local watched = {}
local config = config_mod.load()
local config_at = -1000

local PLACE_ART = {
  menu = "menu",
  level_select = "level_select",
  apartment = "apartment",
  hotel = "hotel",
  factory = "factory",
  club = "club",
  prison = "prison",
  chinatown = "chinatown",
  studio = "studio",
  mansion = "mansion",
  bunker = "bunker",
  lab = "lab",
  cathedral = "cathedral",
  psychiatrist = "psychiatrist",
  bar = "bar",
  rooftop = "rooftop",
  videostore = "videostore",
  dream = "dream",
}

local function large_key(place)
  if config.privacy == "vague" then
    return "katana"
  end
  return PLACE_ART[place] or "katana"
end


local place_key = nil
local chapter_anchor = nil
local run_anchor = nil
local speedrun_active = false
local last_elapsed = nil
local timer_key = nil
local timer_unit = nil
local timer_prev = nil
local timer_prev_clock = nil
local logged_fields = false
local was_paused = false
local deaths = 0
local was_dead = false
local player = nil
local track_key = nil
local track_at = -1000
local choice_line = nil
local choice_at = -1000
local unknown_rooms = {}
local unknown_characters = {}
local last_body = nil

local function clock_now()
  if type(os) == "table" and type(os.clock) == "function" then
    return os.clock()
  end
  return 0
end

local function unix_now()
  if type(os) == "table" and type(os.time) == "function" then
    return os.time()
  end
  return nil
end

local function write_log(message)
  log(message)
  local handle = io.open(config_mod.root .. "discover.log", "a")
  if not handle then
    return
  end
  handle:write(tostring(message), "\n")
  handle:close()
end

local function refresh_config(clock)
  if clock - config_at < 2 then
    return
  end
  config_at = clock
  config = config_mod.load()
end

local function language()
  if config.language == "ru" or config.language == "en" then
    return config.language
  end
  local function normalize(value)
    if type(value) ~= "string" or value == "" then
      return nil
    end
    local lower = value:lower()
    if lower:find("rus", 1, true) or lower:find("ru", 1, true) == 1 then
      return "ru"
    end
    if lower:find("en", 1, true) == 1 or lower:find("eng", 1, true) then
      return "en"
    end
    return nil
  end
  if type(_pGlobal) == "table" then
    for _, key in ipairs({ "language", "lang", "locale", "option_language" }) do
      local parsed = normalize(_pGlobal[key])
      if parsed then
        return parsed
      end
    end
  end
  for _, name in ipairs({ "option_language", "global_language", "language" }) do
    local parsed = normalize(rawget(_G, name))
    if parsed then
      return parsed
    end
  end
  return "en"
end

local function json_string(value)
  local text_value = tostring(value or "")
  text_value = text_value:gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("\r", "\\r"):gsub("\n", "\\n")
  return "\"" .. text_value .. "\""
end

local function encode(snapshot)
  local function field(value)
    if value and value ~= "" then
      return json_string(value)
    end
    return "null"
  end
  local stamp = "null"
  if type(snapshot.timestamp_start) == "number" then
    stamp = string.format("%d", math.floor(snapshot.timestamp_start))
  end
  return string.format(
    "{\"details\":%s,\"state\":%s,\"large_image\":%s,\"large_text\":%s,\"small_image\":%s,\"small_text\":%s,\"timestamp_start\":%s}\n",
    json_string(snapshot.details),
    json_string(snapshot.state),
    field(snapshot.large_image),
    json_string(snapshot.large_text or ""),
    field(snapshot.small_image),
    json_string(snapshot.small_text or ""),
    stamp
  )
end

local function write_snapshot(body)
  if body == last_body then
    return
  end
  local path = config_mod.root .. "presence.json"
  local temporary = path .. ".tmp"
  local handle = io.open(temporary, "w")
  if not handle then
    handle = io.open(path, "w")
    if not handle then
      return
    end
    handle:write(body)
    handle:close()
    last_body = body
    return
  end
  handle:write(body)
  handle:close()
  pcall(os.remove, path)
  local called, renamed = pcall(os.rename, temporary, path)
  if not called or renamed ~= true then
    local direct = io.open(path, "w")
    if direct then
      direct:write(body)
      direct:close()
    end
    os.remove(temporary)
  end
  last_body = body
end

local function room_name()
  local get_name = gml.resolve("room_get_name")
  local id = gml.resolve("room")
  if type(get_name) ~= "function" or type(id) ~= "number" then
    return nil
  end
  local ok, name = pcall(get_name, id)
  if ok and type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

local function is_paused()
  local exists = gml.resolve("instance_exists")
  if type(exists) ~= "function" then
    return false
  end
  for _, name in ipairs({ "obj_pausemenu", "obj_gamepaused" }) do
    local object = gml.resolve(name)
    if object ~= nil then
      local ok, value = pcall(exists, object)
      if ok and gml.truthy(value) then
        return true
      end
    end
  end
  return false
end

local function normalize_character(raw)
  if type(raw) ~= "string" then
    return nil
  end
  local token = raw:lower():match("^%s*(%S+)")
  if token == "15" or token == "gamma" then
    return "fifteen"
  end
  if token == "zero" or token == "fifteen" or token == "snow" then
    return token
  end
  return nil, token
end

local function read_choice(clock)
  if clock - choice_at < 1 then
    return choice_line
  end
  choice_at = clock
  local handle = io.open("kz_character_choice.txt", "r")
  if not handle then
    choice_line = nil
    return nil
  end
  choice_line = handle:read("*l")
  handle:close()
  return choice_line
end

local function character_id(clock)
  local from_file, unknown = normalize_character(read_choice(clock))
  if from_file then
    return from_file
  end
  if unknown and not unknown_characters[unknown] then
    unknown_characters[unknown] = true
    write_log("unknown character '" .. unknown .. "', using Zero")
  end
  local sources = { watched.obj_speedrun_master, player }
  if type(_pGlobal) == "table" then
    sources[#sources + 1] = _pGlobal
  end
  for _, source in ipairs(sources) do
    for _, key in ipairs(CHAR_KEYS) do
      local known, raw_unknown = normalize_character(gml.field(source, key))
      if known then
        return known
      end
      if raw_unknown and not unknown_characters[raw_unknown] then
        unknown_characters[raw_unknown] = true
        write_log("unknown character '" .. raw_unknown .. "', using Zero")
      end
    end
  end
  return "zero"
end

local function plausible_timer(value)
  return type(value) == "number" and value >= 0 and value < 1000000000
end

local function read_keyed_timer(key)
  local value = gml.field(watched.obj_speedrun_master, key)
  if plausible_timer(value) then
    return value
  end
  if type(_pGlobal) == "table" then
    value = _pGlobal[key]
    if plausible_timer(value) then
      return value
    end
  end
  return nil
end

local function classify_rate(delta, dt)
  if not dt or dt <= 0 or not delta or delta <= 0 then
    return nil
  end
  local rate = delta / dt
  if rate > 400 then
    return "ms"
  end
  if rate > 20 then
    return "frames"
  end
  if rate > 0.2 and rate < 5 then
    return "s"
  end
  return nil
end

local function to_seconds(raw)
  if timer_unit == "ms" then
    return raw / 1000
  end
  if timer_unit == "frames" then
    return raw / 60
  end
  return raw
end

local function log_timer_fields()
  if logged_fields then
    return
  end
  logged_fields = true
  local inst = watched.obj_speedrun_master
  if inst == nil then
    write_log("speedrun timer not found")
    return
  end
  local ok, names = pcall(function()
    local list = {}
    for key, value in pairs(inst) do
      if type(value) == "number" then
        list[#list + 1] = tostring(key)
      end
    end
    table.sort(list)
    return table.concat(list, ",")
  end)
  if ok and names ~= "" then
    write_log("speedrun numeric fields: " .. names)
  else
    write_log("speedrun timer fields unreadable")
  end
end

--- nil until the unit (seconds, milliseconds, frames) is known.
local function sample_timer(clock, paused)
  if paused then
    timer_prev = nil
    timer_prev_clock = nil
    return nil
  end
  if timer_key then
    local raw = read_keyed_timer(timer_key)
    if raw == nil then
      speedrun_active = false
      run_anchor = nil
      last_elapsed = nil
      return nil
    end
    return to_seconds(raw)
  end

  local locked_raw = nil
  if type(timer_prev) == "table" and timer_prev_clock then
    local dt = clock - timer_prev_clock
    for _, key in ipairs(TIMER_KEYS) do
      local raw = read_keyed_timer(key)
      local previous = timer_prev[key]
      if raw ~= nil and previous ~= nil then
        local unit = classify_rate(raw - previous, dt)
        if unit then
          timer_key = key
          timer_unit = unit
          locked_raw = raw
          write_log("speedrun field " .. key .. " unit " .. unit)
          break
        end
      end
    end
  end

  timer_prev = {}
  for _, key in ipairs(TIMER_KEYS) do
    local raw = read_keyed_timer(key)
    if raw ~= nil then
      timer_prev[key] = raw
    end
  end
  timer_prev_clock = clock
  if locked_raw == nil and clock > 8 and watched.obj_speedrun_master ~= nil then
    log_timer_fields()
  end
  if locked_raw == nil then
    return nil
  end
  return to_seconds(locked_raw)
end

local function rebase_run(seconds, now)
  local elapsed = math.floor(seconds)
  if elapsed < 0 then
    elapsed = 0
  end
  run_anchor = now - elapsed
  last_elapsed = elapsed
  speedrun_active = true
end

local function consider_run(seconds, now)
  if seconds == nil or now == nil then
    return
  end
  local elapsed = math.floor(seconds)
  if elapsed < 0 then
    elapsed = 0
  end
  local jumped_back = last_elapsed ~= nil and elapsed + 2 < last_elapsed
  if run_anchor == nil or jumped_back then
    rebase_run(seconds, now)
    return
  end
  last_elapsed = elapsed
  speedrun_active = true
end

local function scan_track()
  local playing = gml.resolve("audio_is_playing")
  if type(playing) == "function" then
    for _, name in ipairs(tracks.scan) do
      local id = gml.resolve(name)
      if id ~= nil then
        local ok, on = pcall(playing, id)
        if ok and gml.truthy(on) then
          return tracks.canonical(name)
        end
      end
    end
  end
  local get_name = gml.resolve("audio_get_name")
  local master = watched.obj_musicmaster
  for _, key in ipairs({ "current_song", "song", "music", "bgm", "track" }) do
    local value = gml.field(master, key)
    if type(value) == "string" and value ~= "" then
      return tracks.canonical(value)
    end
    if type(value) == "number" and type(get_name) == "function" then
      local ok, name = pcall(get_name, value)
      if ok and type(name) == "string" and name ~= "" then
        return tracks.canonical(name)
      end
    end
  end
  return nil
end

local function track_title(clock)
  if clock - track_at >= 0.5 then
    track_at = clock
    track_key = scan_track()
  end
  if not track_key then
    return nil
  end
  return tracks.title(track_key) or track_key
end

local function note_death()
  if player == nil then
    return
  end
  local dead = gml.truthy(gml.field(player, "dead")) or gml.truthy(gml.field(player, "dying"))
  if dead and not was_dead then
    deaths = deaths + 1
    was_dead = true
    return
  end
  if not dead then
    was_dead = false
  end
end

local function compose_state(track, paused, lang)
  local parts = {}
  if paused then
    parts[#parts + 1] = text.get(lang, "paused")
  elseif config.privacy ~= "vague" and track and track ~= "" then
    parts[#parts + 1] = track
  end
  if deaths > 0 then
    parts[#parts + 1] = string.format(text.get(lang, "deaths"), deaths)
  end
  return table.concat(parts, " · ")
end

local function details_for(place, lang)
  if config.privacy == "vague" then
    if place == "menu" or place == "level_select" then
      return text.get(lang, "menu")
    end
    if place == "loading" then
      return text.get(lang, "loading")
    end
    return text.get(lang, "mission")
  end
  if place == "unknown" then
    return text.get(lang, "in_game")
  end
  return text.get(lang, place)
end

function Presence.init(ctx)
  if ctx and type(ctx.log) == "function" then
    log = ctx.log
  end
  config = config_mod.load()
end

function Presence.observe(name, self)
  if self ~= nil then
    watched[name] = self
  end
  if name == "obj_player" then
    player = self
  end
end

function Presence.poll()
  local clock = clock_now()
  refresh_config(clock)
  local name = room_name()
  if not name then
    return
  end
  local place = rooms.classify(name)
  if place == "test" then
    return
  end
  if place == "unknown" and not unknown_rooms[name] then
    unknown_rooms[name] = true
    write_log("unknown room " .. name)
  end

  local paused = is_paused()
  local now = unix_now()
  if paused ~= was_paused then
    local resumed = was_paused and not paused
    was_paused = paused
    timer_prev = nil
    timer_prev_clock = nil
    if resumed and now then
      local seconds = sample_timer(clock, false)
      if seconds then
        rebase_run(seconds, now)
      end
    end
  end

  if not paused and clock - (Presence._timer_at or -1000) >= 1 then
    Presence._timer_at = clock
    consider_run(sample_timer(clock, false), now)
  end

  if place ~= place_key then
    place_key = place
    if not speedrun_active and now then
      chapter_anchor = now
    end
  end

  note_death()
  local lang = language()
  local who = character_id(clock)
  local stamp = nil
  if config.show_elapsed and not paused and now then
    if speedrun_active and run_anchor then
      stamp = run_anchor
    else
      stamp = chapter_anchor
    end
  end

  local details = details_for(place, lang)
  local small_text = ""
  if config.privacy ~= "vague" then
    small_text = text.get(lang, who)
  end

  write_snapshot(encode({
    details = details,
    state = compose_state(track_title(clock), paused, lang),
    large_image = large_key(place),
    large_text = details,
    small_image = who,
    small_text = small_text,
    timestamp_start = stamp,
  }))
end

return Presence
