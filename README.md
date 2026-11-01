# KZM Discord

Discord Rich Presence for Katana ZERO through KZM. The status shows where you are, the current track, and the character portrait. A speedrun uses Discord's own clock (`timestamps.start`). The timer is not typed into the status, so it does not keep updating Discord.

## Status

- **Details** — place (menu, level select, chapter, or a short scene). Endings and secret rooms stay unlabeled.
- **State** — track name. Pause replaces it once, and puts the track back when you resume. Session deaths are appended only when the count changes.
- **Clock** — speedrun time while a run is active, otherwise time in the current chapter. Pause clears the clock once. Resume sets it once from the in-game timer.
- **Small image** — Zero, Fifteen, or Snow.

Quiet versions of one song (`song_edm` and `song_edm_far`, neighbor music near and far) count as the same track.

## Setup

1. Create an application at <https://discord.com/developers/applications>. Copy the **Application ID**.
2. Open **Rich Presence → Art Assets** and upload:
   - `assets/avatars/zero.png` as `zero`
   - `assets/avatars/fifteen.png` as `fifteen`
   - `assets/avatars/snow.png` as `snow`
   Use `zero.png` as the application icon as well. The key must match the file name. Until those keys exist, the status is sent without a portrait.
3. Build the native plugin, then the mod:

```bash
bash ./build.sh
kzm build
```

`kzm build` does not compile the DLL. The plugin is 32-bit, same as the game (`i686-pc-windows-msvc`).

4. After the first launch, edit `mods/kzm-discord/discord.toml` in the game folder:

```toml
application_id = "123456789012345678"
language = "auto"      # auto, ru, en
privacy = "chapter"    # chapter or vague
show_elapsed = true
```

`language = "auto"` follows the game language (the same globals KZM already checks). `vague` hides the place, the track, and the character name.

An empty application id does nothing and does not affect the game. If Discord is closed, the plugin retries. Failures go to `mods/kzm-discord/rpc.log`. Unmapped rooms, characters, and speedrun fields go to `discover.log`.

## Character

1. First line of `kz_character_choice.txt` in the game folder (`snow` when Katana SNOW wrote it).
2. Otherwise a character field on the player, the speedrun object, or a global.
3. Otherwise Zero.

## Build check

```bash
cargo test
bash ./build.sh
kzm validate .
kzm plugin verify .
```

Close the game before deploying again. In Discord, a running speedrun clock must not flicker. Changing rooms inside one chapter must not reset it. Resetting the run, pausing, and unpausing each update the status once.

Ideas that are not in this version are listed in [docs/BACKLOG.md](docs/BACKLOG.md).
