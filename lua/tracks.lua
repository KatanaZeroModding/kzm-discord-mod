--- Soundtrack ids from the game name index. Quiet variants share one title.
local ALIAS = {
  song_edm_far = "song_edm",
  song_edm_headphones = "song_edm",
  song_neighbormusic_far = "song_neighbormusic",
  song_nocturne_ambient = "song_nocturne",
  song_psych_drone_begin = "song_psych",
  song_psych_drone_loop = "song_psych",
}

local TITLE = {
  song_bossbattle = "Boss Battle",
  song_bunker_1 = "Bunker",
  song_bunker_2 = "Bunker II",
  song_cathedral = "Cathedral",
  song_chinatown = "Chinatown",
  song_comingdown = "Coming Down",
  song_dragon = "Dragon",
  song_dreambounce = "Dream Bounce",
  song_drivingforce = "Driving Force",
  song_edm = "EDM",
  song_end_of_the_road = "End of the Road",
  song_ending = "Ending",
  song_ending_2 = "Ending II",
  song_fullconfession = "Full Confession",
  song_graveyard = "Graveyard",
  song_graveyard_2 = "Graveyard II",
  song_katanazero = "Katana ZERO",
  song_killyourtv = "Kill Your TV",
  song_levelselect = "Level Select",
  song_limo = "Limo",
  song_mindgames = "Mindgames",
  song_monster = "Monster",
  song_neighbormusic = "Neighbor",
  song_nightmare = "Nightmare",
  song_nocturne = "Nocturne",
  song_nocturne_distorted = "Nocturne (Distorted)",
  song_precathedral = "Pre-Cathedral",
  song_psych = "Psych",
  song_rainonbrick = "Rain on Brick",
  song_redmist = "Red Mist",
  song_rooftop = "Rooftop",
  song_silhouette = "Silhouette",
  song_slaughterhouse = "Slaughterhouse",
  song_sneaky_driver = "Sneaky Driver",
  song_snow = "Snow",
  song_tensemoment = "Tense Moment",
  song_thirddistrict = "Third District",
  song_tiedupatthemoment = "Tied Up at the Moment",
  song_v_theme = "V",
  song_videostore = "Video Store",
  song_volition = "Volition",
  song_youwillneverknow = "You Will Never Know",
}

local SCAN = {
  "song_bossbattle",
  "song_bunker_1",
  "song_bunker_2",
  "song_cathedral",
  "song_chinatown",
  "song_comingdown",
  "song_dragon",
  "song_dreambounce",
  "song_drivingforce",
  "song_edm",
  "song_edm_far",
  "song_edm_headphones",
  "song_end_of_the_road",
  "song_ending",
  "song_ending_2",
  "song_fullconfession",
  "song_graveyard",
  "song_graveyard_2",
  "song_katanazero",
  "song_killyourtv",
  "song_levelselect",
  "song_limo",
  "song_mindgames",
  "song_monster",
  "song_neighbormusic",
  "song_neighbormusic_far",
  "song_nightmare",
  "song_nocturne",
  "song_nocturne_ambient",
  "song_nocturne_distorted",
  "song_precathedral",
  "song_psych_drone_begin",
  "song_psych_drone_loop",
  "song_rainonbrick",
  "song_redmist",
  "song_rooftop",
  "song_silhouette",
  "song_slaughterhouse",
  "song_sneaky_driver",
  "song_snow",
  "song_tensemoment",
  "song_thirddistrict",
  "song_tiedupatthemoment",
  "song_v_theme",
  "song_videostore",
  "song_volition",
  "song_youwillneverknow",
}

local function canonical(name)
  if type(name) ~= "string" then
    return nil
  end
  return ALIAS[name] or name
end

local function title(name)
  local key = canonical(name)
  if not key then
    return nil
  end
  return TITLE[key]
end

return {
  canonical = canonical,
  title = title,
  scan = SCAN,
}
