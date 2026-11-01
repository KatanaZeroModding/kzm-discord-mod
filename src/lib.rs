//! Discord Rich Presence for the KZM mod. The game Lua side writes
//! `mods/kzm-discord/presence.json`. This thread forwards a snapshot only
//! when that file changes, and never more than once every 15 seconds.

mod gate;

use std::ffi::CStr;
use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::thread;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use discord_rich_presence::{activity, DiscordIpc, DiscordIpcClient};
use serde::Deserialize;
use serde_json::Value;

use gate::{image_rejected, plan_send, Plan};

#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
struct Snapshot {
    #[serde(default)]
    details: String,
    #[serde(default)]
    state: String,
    #[serde(default)]
    small_image: Option<String>,
    #[serde(default)]
    small_text: String,
    #[serde(default)]
    timestamp_start: Option<i64>,
}

fn mod_dir() -> PathBuf {
    let game = std::env::current_exe()
        .ok()
        .and_then(|path| path.parent().map(Path::to_path_buf))
        .unwrap_or_else(|| PathBuf::from("."));
    game.join("mods").join("kzm-discord")
}

fn log_line(dir: &Path, message: &str) {
    let _ = fs::create_dir_all(dir);
    let path = dir.join("rpc.log");
    let Ok(mut file) = OpenOptions::new().create(true).append(true).open(path) else {
        return;
    };
    let stamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let _ = writeln!(file, "{stamp} {message}");
}

fn read_app_id(dir: &Path) -> String {
    for name in ["discord.toml", "discord.default.toml"] {
        let Ok(text) = fs::read_to_string(dir.join(name)) else {
            continue;
        };
        if let Some(id) = app_id_from(&text) {
            if !id.is_empty() {
                return id;
            }
        }
    }
    String::new()
}

fn app_id_from(text: &str) -> Option<String> {
    for line in text.lines() {
        let line = line.trim();
        let rest = line.strip_prefix("application_id")?.trim();
        let rest = rest.strip_prefix('=')?.trim();
        let id = rest.trim_matches('"').trim();
        if id.is_empty() || id.chars().any(|c| !c.is_ascii_digit()) {
            return Some(String::new());
        }
        return Some(id.to_string());
    }
    None
}

fn load_snapshot(dir: &Path) -> Option<Snapshot> {
    let text = fs::read_to_string(dir.join("presence.json")).ok()?;
    let mut snap: Snapshot = serde_json::from_str(&text).ok()?;
    if snap.details.is_empty() {
        return None;
    }
    if snap.small_image.as_deref().map(str::is_empty).unwrap_or(false) {
        snap.small_image = None;
    }
    Some(snap)
}

fn activity_from(snap: &Snapshot, with_image: bool) -> activity::Activity<'_> {
    let mut built = activity::Activity::new().details(&snap.details);
    if !snap.state.is_empty() {
        built = built.state(&snap.state);
    }
    if let Some(start) = snap.timestamp_start {
        built = built.timestamps(activity::Timestamps::new().start(start));
    }
    if with_image {
        if let Some(image) = snap.small_image.as_deref().filter(|s| !s.is_empty()) {
            let mut assets = activity::Assets::new().small_image(image);
            if !snap.small_text.is_empty() {
                assets = assets.small_text(&snap.small_text);
            }
            built = built.assets(assets);
        }
    }
    built
}

fn response_error(value: &Value) -> Option<String> {
    let event = value.get("evt").and_then(Value::as_str);
    let code = value.pointer("/data/code");
    if event != Some("ERROR") && code.is_none() {
        return None;
    }
    if event != Some("ERROR") && event.is_some() {
        return None;
    }
    value
        .pointer("/data/message")
        .and_then(Value::as_str)
        .map(str::to_string)
        .or_else(|| Some(value.to_string()))
}

fn push(client: &mut DiscordIpcClient, snap: &Snapshot, with_image: bool) -> Result<(), String> {
    client
        .set_activity(activity_from(snap, with_image))
        .map_err(|err| err.to_string())?;
    let (_opcode, value) = client.recv().map_err(|err| err.to_string())?;
    if let Some(message) = response_error(&value) {
        return Err(message);
    }
    Ok(())
}

enum SendOutcome {
    Idle,
    Wait,
    Clear,
    Sent(Snapshot),
    Failed(String),
}

fn connect(app_id: &str) -> Result<DiscordIpcClient, String> {
    let mut client = DiscordIpcClient::new(app_id).map_err(|err| err.to_string())?;
    client.connect().map_err(|err| err.to_string())?;
    Ok(client)
}

fn run() {
    let dir = mod_dir();
    let mut client: Option<DiscordIpcClient> = None;
    let mut allow_image = true;
    let mut pending: Option<Snapshot> = None;
    let mut last_sent: Option<Snapshot> = None;
    let mut last_send: Option<Instant> = None;
    let mut next_connect = Instant::now();
    let mut missing_id_logged = false;
    let mut last_error_log = Instant::now() - Duration::from_secs(120);

    loop {
        if client.is_none() && Instant::now() >= next_connect {
            let app_id = read_app_id(&dir);
            if app_id.is_empty() {
                if !missing_id_logged {
                    log_line(&dir, "application_id is empty; presence is idle");
                    missing_id_logged = true;
                }
                next_connect = Instant::now() + Duration::from_secs(5);
            } else {
                match connect(&app_id) {
                    Ok(ready) => {
                        client = Some(ready);
                        allow_image = true;
                        last_sent = None;
                        last_send = None;
                        missing_id_logged = false;
                        log_line(&dir, "connected");
                    }
                    Err(err) => {
                        if last_error_log.elapsed() >= Duration::from_secs(30) {
                            log_line(&dir, &format!("connect failed: {err}"));
                            last_error_log = Instant::now();
                        }
                        next_connect = Instant::now() + Duration::from_secs(5);
                    }
                }
            }
        }

        if let Some(snap) = load_snapshot(&dir) {
            if pending.as_ref() != Some(&snap) && last_sent.as_ref() != Some(&snap) {
                pending = Some(snap);
            } else if last_sent.as_ref() == Some(&snap) {
                pending = None;
            }
        }

        let outcome = if let (Some(api), Some(snap)) = (client.as_mut(), pending.clone()) {
            let since = last_send.map(|at| at.elapsed());
            match plan_send(true, last_sent.is_some(), since) {
                Plan::Skip => SendOutcome::Clear,
                Plan::Wait => SendOutcome::Wait,
                Plan::Send => match push(api, &snap, allow_image && snap.small_image.is_some()) {
                    Ok(()) => SendOutcome::Sent(snap),
                    Err(err) if allow_image && image_rejected(&err) => {
                        allow_image = false;
                        log_line(
                            &dir,
                            &format!("asset rejected, retrying without image: {err}"),
                        );
                        match push(api, &snap, false) {
                            Ok(()) => SendOutcome::Sent(snap),
                            Err(retry) => SendOutcome::Failed(retry),
                        }
                    }
                    Err(err) => SendOutcome::Failed(err),
                },
            }
        } else {
            SendOutcome::Idle
        };
        match outcome {
            SendOutcome::Sent(snap) => {
                last_sent = Some(snap);
                last_send = Some(Instant::now());
                pending = None;
            }
            SendOutcome::Failed(err) => {
                log_line(&dir, &format!("send failed: {err}"));
                client = None;
                next_connect = Instant::now() + Duration::from_secs(5);
            }
            SendOutcome::Clear => pending = None,
            SendOutcome::Wait | SendOutcome::Idle => {}
        }

        thread::sleep(Duration::from_millis(200));
    }
}

fn copy_id(mod_id: *const std::os::raw::c_char) -> String {
    if mod_id.is_null() {
        return "kzm-discord".to_string();
    }
    unsafe { CStr::from_ptr(mod_id).to_string_lossy().into_owned() }
}

/// Called once by kzm_host. `extern "system"` matches the host's stdcall call on x86.
#[no_mangle]
pub extern "system" fn KZM_PluginInit(mod_id: *const std::os::raw::c_char) -> i32 {
    let _id = copy_id(mod_id);
    let started = thread::Builder::new()
        .name("kzm-discord".to_string())
        .spawn(run);
    if started.is_err() {
        log_line(&mod_dir(), "failed to start presence thread");
    }
    0
}
