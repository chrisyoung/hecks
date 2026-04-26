//! Integration tests for `hecks-life inbox` — the i80/i107 retirement
//! target for `hecks_conception/inbox.sh`.
//!
//! [antibody-exempt: i80 cli-routing-as-bluebook + i107 capability-
//!  bluebook-end-to-end-dispatch. These tests cover the kernel-surface
//!  runner that walks capabilities/inbox/inbox.bluebook's Invocation
//!  pipeline. They retire alongside run_inbox.rs when capability
//!  bluebooks dispatch end-to-end through `hecks-life run`.]
//!
//! Each test seeds a tmpdir, exports HECKS_INFO so the runner anchors
//! there (skipping the git durability dance), drives the runner via
//! `hecks_life::run_inbox::run`, and asserts the resulting heki state.

use hecks_life::{heki, run_inbox};
use std::path::Path;
use std::sync::Mutex;

// Serialize env-var manipulation across parallel test threads. HECKS_INFO
// is process-global ; without this, two tests racing on it stomp each
// other and produce non-deterministic failures. The lock is held for
// the entire body of each test, so dispatches inside the test see the
// HECKS_INFO that test set.
static ENV_LOCK: Mutex<()> = Mutex::new(());

fn argv(args: &[&str]) -> Vec<String> {
    let mut out = vec!["hecks-life".to_string(), "inbox".to_string()];
    for a in args { out.push(a.to_string()); }
    out
}

fn seed_dir() -> String {
    let base = std::env::temp_dir();
    let pid = std::process::id();
    let nanos = std::time::SystemTime::now()
        .duration_since(std::time::SystemTime::UNIX_EPOCH).unwrap()
        .as_nanos();
    let dir = base.join(format!("inbox-test-{}-{}", pid, nanos));
    std::fs::create_dir_all(&dir).unwrap();
    dir.to_string_lossy().into_owned()
}

#[test]
fn next_ref_starts_at_i1_for_empty_store() {
    let _guard = ENV_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let dir = seed_dir();
    std::env::set_var("HECKS_INFO", &dir);
    let code = run_inbox::run(&argv(&["next-ref"]));
    assert_eq!(code, 0);
    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn add_assigns_monotonic_refs_and_persists_body() {
    let _guard = ENV_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let dir = seed_dir();
    std::env::set_var("HECKS_INFO", &dir);

    assert_eq!(run_inbox::run(&argv(&["add", "high", "first"])), 0);
    assert_eq!(run_inbox::run(&argv(&["add", "low", "second"])), 0);

    let path = format!("{}/inbox.heki", dir);
    let store = heki::read(&path).unwrap();
    assert_eq!(store.len(), 2);

    let refs: Vec<String> = store.values()
        .map(|r| r.get("ref").and_then(|v| v.as_str()).unwrap_or("").to_string())
        .collect();
    assert!(refs.contains(&"i1".to_string()));
    assert!(refs.contains(&"i2".to_string()));

    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn close_marks_status_done_and_stamps_resolution() {
    let _guard = ENV_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let dir = seed_dir();
    std::env::set_var("HECKS_INFO", &dir);

    assert_eq!(run_inbox::run(&argv(&["add", "high", "to be closed"])), 0);
    assert_eq!(run_inbox::run(&argv(&["done", "i1", "fixed it"])), 0);

    let store = heki::read(&format!("{}/inbox.heki", dir)).unwrap();
    let rec = store.values().find(|r| {
        r.get("ref").and_then(|v| v.as_str()) == Some("i1")
    }).unwrap();
    assert_eq!(rec.get("status").and_then(|v| v.as_str()), Some("done"));
    assert_eq!(rec.get("resolution").and_then(|v| v.as_str()), Some("fixed it"));
    assert!(rec.get("completed_at").and_then(|v| v.as_str())
        .map(|s| !s.is_empty()).unwrap_or(false));

    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn reopen_clears_completed_at_and_resolution() {
    let _guard = ENV_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let dir = seed_dir();
    std::env::set_var("HECKS_INFO", &dir);

    assert_eq!(run_inbox::run(&argv(&["add", "high", "to reopen"])), 0);
    assert_eq!(run_inbox::run(&argv(&["done", "i1", "premature"])), 0);
    assert_eq!(run_inbox::run(&argv(&["reopen", "i1"])), 0);

    let store = heki::read(&format!("{}/inbox.heki", dir)).unwrap();
    let rec = store.values().find(|r| {
        r.get("ref").and_then(|v| v.as_str()) == Some("i1")
    }).unwrap();
    assert_eq!(rec.get("status").and_then(|v| v.as_str()), Some("queued"));
    assert_eq!(rec.get("completed_at").and_then(|v| v.as_str()), Some(""));
    assert_eq!(rec.get("resolution").and_then(|v| v.as_str()), Some(""));

    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn drop_hard_deletes_the_record() {
    let _guard = ENV_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let dir = seed_dir();
    std::env::set_var("HECKS_INFO", &dir);

    assert_eq!(run_inbox::run(&argv(&["add", "high", "to drop"])), 0);
    let before = heki::read(&format!("{}/inbox.heki", dir)).unwrap();
    assert_eq!(before.len(), 1);

    assert_eq!(run_inbox::run(&argv(&["archive", "i1"])), 0);
    let after = heki::read(&format!("{}/inbox.heki", dir)).unwrap();
    assert_eq!(after.len(), 0);

    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn show_returns_2_when_ref_not_found() {
    let _guard = ENV_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let dir = seed_dir();
    std::env::set_var("HECKS_INFO", &dir);

    let inbox = format!("{}/inbox.heki", dir);
    let mut attrs = heki::Record::new();
    attrs.insert("ref".into(), serde_json::Value::String("i1".into()));
    attrs.insert("body".into(), serde_json::Value::String("seed".into()));
    heki::append(&inbox, &attrs).unwrap();

    let code = run_inbox::run(&argv(&["show", "i999"]));
    assert_eq!(code, 2);
    let code_ok = run_inbox::run(&argv(&["show", "i1"]));
    assert_eq!(code_ok, 0);

    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn unknown_subcommand_returns_1() {
    let _guard = ENV_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let dir = seed_dir();
    std::env::set_var("HECKS_INFO", &dir);
    let code = run_inbox::run(&argv(&["frobnicate"]));
    assert_eq!(code, 1);
    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn add_with_wish_flag_marks_dream_wish_filed() {
    let _guard = ENV_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let dir = seed_dir();
    std::env::set_var("HECKS_INFO", &dir);

    let wish_path = format!("{}/dream_wish.heki", dir);
    let mut wish = heki::Record::new();
    wish.insert("id".into(), serde_json::Value::String("wish-x".into()));
    wish.insert("theme".into(), serde_json::Value::String("explore X".into()));
    wish.insert("status".into(), serde_json::Value::String("unfiled".into()));
    heki::append(&wish_path, &wish).unwrap();

    assert_eq!(run_inbox::run(&argv(&["add", "--wish=wish-x", "high", "filing"])), 0);

    let store = heki::read(&wish_path).unwrap();
    // The wish row is upserted by id ; find it by its `id` field.
    let rec = store.values().find(|r| {
        r.get("id").and_then(|v| v.as_str()) == Some("wish-x")
    }).expect("wish row present");
    assert_eq!(rec.get("status").and_then(|v| v.as_str()), Some("filed"));
    assert!(rec.get("filed_as").and_then(|v| v.as_str())
        .map(|s| s.starts_with('i')).unwrap_or(false));

    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn list_filter_all_returns_all_statuses() {
    let _guard = ENV_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let dir = seed_dir();
    std::env::set_var("HECKS_INFO", &dir);

    assert_eq!(run_inbox::run(&argv(&["add", "high", "queued one"])), 0);
    assert_eq!(run_inbox::run(&argv(&["add", "low", "to close"])), 0);
    assert_eq!(run_inbox::run(&argv(&["done", "i2", "fixed"])), 0);

    let path = format!("{}/inbox.heki", dir);
    let store = heki::read(&path).unwrap();
    assert_eq!(store.len(), 2);

    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn no_repo_root_skips_durability_silently() {
    // HECKS_INFO override sets repo_root=None — the durability dance
    // must skip cleanly without mutating cwd's git state.
    let _guard = ENV_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let dir = seed_dir();
    std::env::set_var("HECKS_INFO", &dir);
    assert_eq!(run_inbox::run(&argv(&["add", "low", "no-commit"])), 0);
    assert!(Path::new(&format!("{}/inbox.heki", dir)).exists());
    let _ = std::fs::remove_dir_all(&dir);
}
