// Innovate Remote licence check (Oct 3 2026).
//
// Every install of Innovate Remote is a licence. The installer registers this PC (its Remote ID) under a
// firm on license.taquiai.ai and writes the firm id into this app's options ("innovate-firm-id").
// From then on the app asks the licence server "am I still allowed?" at start and every 30 minutes.
// If Innovate suspends this one install (or the whole firm), the answer turns to "no" and this PC refuses
// incoming connections and cannot start outgoing ones. A short outage never locks a PC out: the last
// "yes" is remembered for 72 hours. Only the Remote ID, firm id and app version are sent - never screen
// content or anything about the connections.
use hbb_common::{config::Config, log};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Once;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

const VERIFY_URL: &str = "https://license.taquiai.ai/api/remote/verify";
const GRACE_SECS: u64 = 72 * 3600;
const CHECK_EVERY: Duration = Duration::from_secs(30 * 60);
const RETRY_EVERY: Duration = Duration::from_secs(120);

static ALLOWED: AtomicBool = AtomicBool::new(false);
static START: Once = Once::new();
static FIRST_DONE: AtomicBool = AtomicBool::new(false);

fn now_secs() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

fn stamp_path() -> std::path::PathBuf {
    Config::path("innovate_license.txt")
}

fn last_ok() -> u64 {
    std::fs::read_to_string(stamp_path())
        .ok()
        .and_then(|s| s.trim().parse::<u64>().ok())
        .unwrap_or(0)
}

fn within_grace() -> bool {
    let t = last_ok();
    t > 0 && now_secs().saturating_sub(t) < GRACE_SECS
}

// Only called from the checker thread (never from async code): the GUI process asks the service over IPC.
fn firm_id() -> String {
    if crate::is_server() {
        Config::get_option("innovate-firm-id").trim().to_owned()
    } else {
        crate::ipc::get_options()
            .get("innovate-firm-id")
            .cloned()
            .unwrap_or_default()
            .trim()
            .to_owned()
    }
}

fn my_id() -> String {
    if crate::is_server() {
        Config::get_id()
    } else {
        crate::ipc::get_id()
    }
}

/// Asks the licence server once. Returns true when the server answered (yes or no), false when it could not be reached.
fn check_once_inner() -> bool {
    let firm = firm_id();
    if firm.is_empty() {
        // not installed through the Innovate installer: no licence, no connections
        ALLOWED.store(false, Ordering::SeqCst);
        return false; // asked again in 2 minutes: the installer may be about to write the firm id
    }
    let url = format!(
        "{}?firm_id={}&remote_id={}&version={}",
        VERIFY_URL,
        firm,
        my_id(),
        env!("CARGO_PKG_VERSION")
    );
    let client = crate::hbbs_http::create_http_client_with_url(&url);
    let resp = match client.get(&url).timeout(Duration::from_secs(20)).send() {
        Ok(r) => r,
        Err(e) => {
            log::warn!("licence check could not reach the server: {}", e);
            ALLOWED.store(within_grace(), Ordering::SeqCst);
            return false;
        }
    };
    match resp.json::<serde_json::Value>() {
        Ok(v) => {
            let allowed = v.get("allowed").and_then(|a| a.as_bool()).unwrap_or(false);
            if allowed {
                std::fs::write(stamp_path(), now_secs().to_string()).ok();
            } else {
                // a "no" is final at once: it also wipes the remembered "yes"
                std::fs::remove_file(stamp_path()).ok();
                log::warn!(
                    "Innovate Remote licence is not active: {}",
                    v.get("reason").and_then(|r| r.as_str()).unwrap_or("unknown")
                );
            }
            ALLOWED.store(allowed, Ordering::SeqCst);
            allowed // a "no" is asked again every 2 minutes, so a registration or a resume takes effect quickly
        }
        Err(e) => {
            log::warn!("licence check got an unreadable answer: {}", e);
            ALLOWED.store(within_grace(), Ordering::SeqCst);
            false
        }
    }
}

fn check_once() -> bool {
    let r = check_once_inner();
    FIRST_DONE.store(true, Ordering::SeqCst);
    r
}

fn ensure_started() {
    START.call_once(|| {
        // until the first answer arrives, trust a recent "yes" from before a restart
        ALLOWED.store(within_grace(), Ordering::SeqCst);
        std::thread::spawn(|| loop {
            let reached = check_once();
            std::thread::sleep(if reached { CHECK_EVERY } else { RETRY_EVERY });
        });
    });
}

/// True when this install is licensed right now.
pub fn allowed() -> bool {
    ensure_started();
    // the very first answer takes a second or two: wait for it (up to 6 s) instead of refusing the first connection
    let mut waited = 0;
    while !FIRST_DONE.load(Ordering::SeqCst) && waited < 30 {
        std::thread::sleep(Duration::from_millis(200));
        waited += 1;
    }
    ALLOWED.load(Ordering::SeqCst)
}

/// Tells the licence server that a session started on this PC ("in": someone connected to it, "out": this PC connected to another). Fire and forget on its own thread:
/// a failure or a slow server never delays or blocks the connection. Only this PC's own ID and the direction are sent - never who connected or anything on screen.
pub fn report_session(direction: &'static str) {
    std::thread::spawn(move || {
        let firm = firm_id();
        if firm.is_empty() {
            return;
        }
        let url = format!(
            "https://license.taquiai.ai/api/remote/session?firm_id={}&remote_id={}&direction={}",
            firm,
            my_id(),
            direction
        );
        let client = crate::hbbs_http::create_http_client_with_url(&url);
        if let Err(e) = client.get(&url).timeout(Duration::from_secs(15)).send() {
            log::debug!("session report not sent: {}", e);
        }
    });
}

/// Starts the checker at program start, so the licence is already known when the first connection arrives.
pub fn start() {
    ensure_started();
}

/// The message shown when a connection is refused for licence reasons.
pub const REFUSED: &str = "Innovate Remote licence is not active on this PC. Please contact Innovate.";
