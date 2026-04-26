//! Inbox capability runner — `hecks-life inbox <subcommand> [args]`
//!
//! [antibody-exempt: i80 cli-routing-as-bluebook + i107 capability-
//!  bluebook-end-to-end-dispatch + i106 :git-adapter-shell-sequence-
//!  primitive. This module IS the structural rewrite that retires
//!  hecks_conception/inbox.sh : it walks capabilities/inbox/inbox.
//!  bluebook's Invocation pipeline (route → resolve → dispatch →
//!  commit → push → render → exit) and dispatches via the heki
//!  primitives the bluebook names. The shell collapses to one
//!  `exec hecks-life inbox "$@"` line. Retires when (a) i101 query
//!  IR lets the runtime execute Item.* queries declaratively, (b)
//!  i106 :git adapter replaces the std::process::Command git dance,
//!  (c) i107 routes any capability bluebook through `hecks-life run`
//!  without a per-capability Rust runner — at which point this
//!  module collapses too.]
//!
//! Walks the shape declared in `capabilities/inbox/inbox.bluebook` —
//! subcommand → Item command or query → render → durability dance —
//! using the existing heki primitives + `git` via std::process::Command.
//!
//! This is the i80 "cli-routing-as-bluebook" foothold for the inbox
//! capability and the i107 retirement target ("runtime cannot dispatch
//! a capability bluebook end-to-end yet"). It collapses inbox.sh from
//! a 218-line imperative dispatcher into a one-line `exec hecks-life
//! inbox "$@"` wrapper.
//!
//! Subcommands (mirror inbox.sh's surface so existing call sites — the
//! mindstream awareness snapshot, dream-wish receipts, hooks — keep
//! working unchanged) :
//!
//!   inbox add [--wish=<id>] <priority> <body>   → assigns next ref, prints it
//!   inbox list [queued|done|all]                → table view (queued by default)
//!   inbox show <ref>                            → full body block
//!   inbox get  <ref>                            → alias of show
//!   inbox done <ref> [resolution]               → mark done + stamp completed_at
//!   inbox close <ref> [resolution]              → alias of done (matches bluebook vocab)
//!   inbox reopen <ref>                          → done → queued (preserves ref)
//!   inbox archive <ref>                         → hard-delete (legacy alias)
//!   inbox drop <ref>                            → alias of archive (matches bluebook vocab)
//!   inbox next-ref                              → print next monotonic ref
//!
//! The durability dance after every write — auto-commit on the
//! operator's branch + push the same heki content to origin/main via a
//! temporary worktree — mirrors what inbox.sh did. The bluebook names
//! it CommitLocal + PushToMain ; the runtime gap is i106 (`:git`
//! adapter / shell-sequence primitive). Until that lands, this module
//! invokes git imperatively via std::process::Command, with the same
//! loud-warning failure modes as the shell predecessor.
//!
//! Exit codes :
//!   0 clean
//!   1 parse failure (missing args, unknown subcommand)
//!   2 guard failure (no item with that ref)
//!   3 adapter failure (heki write failed)

use crate::heki;
use crate::heki_query::{self, Filter, FilterOp, OrderDir, OrderSpec};

use std::path::{Path, PathBuf};
use std::process::Command;

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

/// argv is `["hecks-life", "inbox", <sub>, ...rest]`.
pub fn run(args: &[String]) -> i32 {
    if args.len() < 3 {
        print_usage();
        return 1;
    }
    let sub = args[2].as_str();
    let rest = &args[3..];

    let dirs = match resolve_dirs() {
        Some(d) => d,
        None => {
            eprintln!("inbox: cannot locate hecks_conception/information/ — run from a hecks checkout");
            return 1;
        }
    };

    match sub {
        "add"               => cmd_add(rest, &dirs),
        "list"              => cmd_list(rest, &dirs),
        "show" | "get"      => cmd_show(rest, &dirs),
        "done" | "close"    => cmd_close(rest, &dirs),
        "reopen"            => cmd_reopen(rest, &dirs),
        "archive" | "drop"  => cmd_drop(rest, &dirs),
        "next-ref"          => cmd_next_ref(&dirs),
        "--help" | "-h"     => { print_usage(); 0 }
        other => {
            eprintln!("inbox: unknown subcommand: {}", other);
            print_usage();
            1
        }
    }
}

fn print_usage() {
    eprintln!("usage: hecks-life inbox <subcommand> [args]");
    eprintln!("subcommands:");
    eprintln!("  add [--wish=<id>] <priority> <body>");
    eprintln!("  list [queued|done|all]");
    eprintln!("  show <ref>      (alias: get)");
    eprintln!("  done <ref> [resolution]   (alias: close)");
    eprintln!("  reopen <ref>");
    eprintln!("  archive <ref>   (alias: drop)");
    eprintln!("  next-ref");
}

// ---------------------------------------------------------------------------
// Directory resolution — anchored on hecks_conception/information/
// ---------------------------------------------------------------------------

struct Dirs {
    inbox_heki: String,
    wish_heki: String,
    /// The conception's parent — the git repo root. Used by the
    /// durability dance to spawn a worktree against origin/main.
    repo_root: Option<String>,
    /// hecks_conception/information/inbox.heki relative to repo_root,
    /// for the worktree-side `cp` inside PushToMain.
    inbox_relpath: String,
}

fn resolve_dirs() -> Option<Dirs> {
    // Honor HECKS_INFO override first (tests + production seeding).
    if let Ok(info) = std::env::var("HECKS_INFO") {
        if !info.is_empty() {
            return Some(Dirs {
                inbox_heki: format!("{}/inbox.heki", info),
                wish_heki:  format!("{}/dream_wish.heki", info),
                repo_root:  None,
                inbox_relpath: "hecks_conception/information/inbox.heki".into(),
            });
        }
    }
    // Walk up from each candidate root: first cwd (lets users `cd` into
    // a subdir and run `hecks-life inbox` directly), then the binary's
    // own directory (so the inbox.sh wrapper works regardless of cwd —
    // matches how status.sh anchors). Each candidate gets up to six
    // levels of parent walking.
    let candidates: Vec<PathBuf> = vec![
        std::env::current_dir().ok(),
        std::env::current_exe().ok(),
    ].into_iter().flatten().collect();
    for start in candidates {
        let mut cur: PathBuf = start;
        // current_exe() returns the binary path ; pop to the dir.
        if cur.is_file() { cur.pop(); }
        for _ in 0..8 {
            let info = cur.join("hecks_conception/information");
            if info.is_dir() {
                return Some(Dirs {
                    inbox_heki: info.join("inbox.heki").to_string_lossy().into(),
                    wish_heki:  info.join("dream_wish.heki").to_string_lossy().into(),
                    repo_root:  Some(cur.to_string_lossy().into()),
                    inbox_relpath: "hecks_conception/information/inbox.heki".into(),
                });
            }
            // Inside hecks_conception itself.
            let here = cur.join("information");
            if here.is_dir() && cur.file_name().map(|n| n == "hecks_conception").unwrap_or(false) {
                let parent = cur.parent().map(|p| p.to_string_lossy().into_owned());
                return Some(Dirs {
                    inbox_heki: here.join("inbox.heki").to_string_lossy().into(),
                    wish_heki:  here.join("dream_wish.heki").to_string_lossy().into(),
                    repo_root:  parent,
                    inbox_relpath: "hecks_conception/information/inbox.heki".into(),
                });
            }
            if !cur.pop() { break; }
        }
    }
    None
}

// ---------------------------------------------------------------------------
// next-ref — Item.NextRef query (i101 equivalent — until query IR lands)
// ---------------------------------------------------------------------------

fn cmd_next_ref(dirs: &Dirs) -> i32 {
    println!("{}", next_ref(&dirs.inbox_heki));
    0
}

fn next_ref(path: &str) -> String {
    let store = match heki::read(path) {
        Ok(s) => s,
        Err(_) => return "i1".into(),
    };
    let mut max_n: i64 = 0;
    for rec in store.values() {
        let v = heki_query::field_to_string(rec.get("ref"));
        if let Some(tail) = v.strip_prefix('i') {
            if let Ok(n) = tail.parse::<i64>() {
                if n > max_n { max_n = n; }
            }
        }
    }
    format!("i{}", max_n + 1)
}

// ---------------------------------------------------------------------------
// add — Item.Add (+ optional DreamWish.MarkFiled)
// ---------------------------------------------------------------------------

fn cmd_add(rest: &[String], dirs: &Dirs) -> i32 {
    // Parse --wish=<id> flag and positional priority + body.
    let mut wish_id = String::new();
    let mut positional: Vec<String> = Vec::new();
    for a in rest {
        if let Some(v) = a.strip_prefix("--wish=") {
            wish_id = v.to_string();
        } else {
            positional.push(a.clone());
        }
    }
    if positional.len() < 2 {
        eprintln!("usage: inbox add [--wish=<id>] <priority> <body>");
        return 1;
    }
    let priority = &positional[0];
    let body = &positional[1];
    let now = heki::now_iso();
    let ref_ = next_ref(&dirs.inbox_heki);

    let mut attrs = heki::Record::new();
    attrs.insert("ref".into(),       serde_json::Value::String(ref_.clone()));
    attrs.insert("priority".into(),  serde_json::Value::String(priority.clone()));
    attrs.insert("status".into(),    serde_json::Value::String("queued".into()));
    attrs.insert("posted_at".into(), serde_json::Value::String(now.clone()));
    attrs.insert("body".into(),      serde_json::Value::String(body.clone()));
    if !wish_id.is_empty() {
        attrs.insert("wish_id".into(), serde_json::Value::String(wish_id.clone()));
    }
    if let Err(e) = heki::append(&dirs.inbox_heki, &attrs) {
        eprintln!("inbox: heki append failed: {}", e);
        return 3;
    }

    // Cross-aggregate dispatch — DreamWish.MarkFiled. The bluebook
    // declares this as a consumer-contract trigger ; until i98's
    // dispatch path is wired through the runtime, mutate the wish
    // store directly.
    //
    // Wishes are stored under UUID store keys with the wish_id as a
    // FIELD ; the bluebook treats that field as the wish's identity
    // for cross-aggregate references. Find the row by field, mutate
    // in place, write the store back. heki::upsert can't do this
    // directly because its `id` attr binds to the STORE KEY, which
    // would overwrite the wish's identity field with the UUID. (The
    // old inbox.sh comment named this gap as "lookup-by-id for
    // non-singleton aggregates currently misroutes".)
    if !wish_id.is_empty() && Path::new(&dirs.wish_heki).exists() {
        if let Ok(mut store) = heki::read(&dirs.wish_heki) {
            let key = store.iter()
                .find(|(_, rec)| heki_query::field_to_string(rec.get("id")) == wish_id)
                .map(|(k, _)| k.clone());
            if let Some(k) = key {
                if let Some(rec) = store.get_mut(&k) {
                    rec.insert("status".into(),   serde_json::Value::String("filed".into()));
                    rec.insert("filed_as".into(), serde_json::Value::String(ref_.clone()));
                    rec.insert("filed_at".into(), serde_json::Value::String(now.clone()));
                    rec.insert("updated_at".into(), serde_json::Value::String(now.clone()));
                    let _ = heki::write(&dirs.wish_heki, &store);
                }
            }
        }
    }

    // Durability — CommitLocal + PushToMain via the :shell adapter (i106).
    let subject = commit_subject(&ref_, body);
    durability_dance(dirs, &subject);

    println!("{}", ref_);
    0
}

// ---------------------------------------------------------------------------
// list — Item.ListAll / ListQueued / ListDone (until i101 query IR lands)
// ---------------------------------------------------------------------------

fn cmd_list(rest: &[String], dirs: &Dirs) -> i32 {
    let filter = rest.first().map(|s| s.as_str()).unwrap_or("queued");
    let store = match heki::read(&dirs.inbox_heki) {
        Ok(s) => s,
        Err(e) => { eprintln!("inbox: {}", e); return 3; }
    };
    let filters: Vec<Filter> = if filter == "all" {
        Vec::new()
    } else {
        vec![Filter { field: "status".into(), op: FilterOp::Eq, value: filter.into() }]
    };
    let recs = heki_query::filter_records(&store, &filters);
    let orders = vec![
        OrderSpec {
            field: "priority".into(),
            dir: OrderDir::Asc,
            enum_order: Some(vec!["high".into(), "medium".into(), "normal".into(), "low".into()]),
            numeric_ref: false,
        },
        OrderSpec {
            field: "ref".into(),
            dir: OrderDir::Asc,
            enum_order: None,
            numeric_ref: true,
        },
    ];
    let recs = heki_query::order_records_multi(recs, &orders);
    for rec in recs {
        let r = heki_query::field_to_string(rec.get("ref"));
        let p = heki_query::field_to_string(rec.get("priority"));
        let s = heki_query::field_to_string(rec.get("status"));
        let b = heki_query::field_to_string(rec.get("body"))
            .replace('\n', " ");
        let r = if r.is_empty() { "—".to_string() } else { r };
        let p = take6(&p);
        let s = take8(&s);
        let b = take_chars(&b, 90);
        println!("  {:>5}  [{:<6}/{:<6}]  {}", r, p, s, b);
    }
    0
}

fn take6(s: &str)  -> String { take_chars(s, 6) }
fn take8(s: &str)  -> String { take_chars(s, 8) }
fn take_chars(s: &str, n: usize) -> String {
    s.chars().take(n).collect()
}

// ---------------------------------------------------------------------------
// show / get — Item.GetByRef + render
// ---------------------------------------------------------------------------

fn cmd_show(rest: &[String], dirs: &Dirs) -> i32 {
    let ref_ = match rest.first() {
        Some(s) => s.as_str(),
        None => { eprintln!("usage: inbox show <ref>"); return 1; }
    };
    let (uuid, rec) = match resolve_ref(ref_, &dirs.inbox_heki) {
        Some(x) => x,
        None => { eprintln!("inbox: no item with ref {}", ref_); return 2; }
    };
    let f = |k: &str| heki_query::field_to_string(rec.get(k));
    println!("ref:         {}", f("ref"));
    println!("uuid:        {}", uuid);
    println!("priority:    {}", f("priority"));
    println!("status:      {}", f("status"));
    println!("posted_at:   {}", f("posted_at"));
    let completed = f("completed_at");
    if !completed.is_empty() { println!("completed_at: {}", completed); }
    let resolution = f("resolution");
    if !resolution.is_empty() { println!("resolution:   {}", resolution); }
    println!();
    println!("{}", f("body"));
    0
}

// ---------------------------------------------------------------------------
// done / close — Item.Close (status=done, stamp completed_at + resolution)
// ---------------------------------------------------------------------------

fn cmd_close(rest: &[String], dirs: &Dirs) -> i32 {
    let ref_ = match rest.first() {
        Some(s) => s.as_str(),
        None => { eprintln!("usage: inbox done <ref> [resolution]"); return 1; }
    };
    let resolution = rest.get(1).cloned().unwrap_or_else(|| "done".into());
    let (uuid, _rec) = match resolve_ref(ref_, &dirs.inbox_heki) {
        Some(x) => x,
        None => { eprintln!("inbox: no item with ref {}", ref_); return 2; }
    };
    let now = heki::now_iso();
    let mut attrs = heki::Record::new();
    attrs.insert("id".into(),           serde_json::Value::String(uuid));
    attrs.insert("status".into(),       serde_json::Value::String("done".into()));
    attrs.insert("completed_at".into(), serde_json::Value::String(now));
    attrs.insert("resolution".into(),   serde_json::Value::String(resolution));
    if let Err(e) = heki::upsert(&dirs.inbox_heki, &attrs) {
        eprintln!("inbox: heki upsert failed: {}", e);
        return 3;
    }
    let subject = format!("inbox({}): close", ref_);
    durability_dance(dirs, &subject);
    println!("closed {}", ref_);
    0
}

// ---------------------------------------------------------------------------
// reopen — Item.Reopen (status=queued, clear completed_at + resolution)
// ---------------------------------------------------------------------------

fn cmd_reopen(rest: &[String], dirs: &Dirs) -> i32 {
    let ref_ = match rest.first() {
        Some(s) => s.as_str(),
        None => { eprintln!("usage: inbox reopen <ref>"); return 1; }
    };
    let (uuid, _rec) = match resolve_ref(ref_, &dirs.inbox_heki) {
        Some(x) => x,
        None => { eprintln!("inbox: no item with ref {}", ref_); return 2; }
    };
    let mut attrs = heki::Record::new();
    attrs.insert("id".into(),           serde_json::Value::String(uuid));
    attrs.insert("status".into(),       serde_json::Value::String("queued".into()));
    attrs.insert("completed_at".into(), serde_json::Value::String(String::new()));
    attrs.insert("resolution".into(),   serde_json::Value::String(String::new()));
    if let Err(e) = heki::upsert(&dirs.inbox_heki, &attrs) {
        eprintln!("inbox: heki upsert failed: {}", e);
        return 3;
    }
    let subject = format!("inbox({}): reopen", ref_);
    durability_dance(dirs, &subject);
    println!("reopened {}", ref_);
    0
}

// ---------------------------------------------------------------------------
// archive / drop — Item.Drop (hard delete after the transition fires)
// ---------------------------------------------------------------------------

fn cmd_drop(rest: &[String], dirs: &Dirs) -> i32 {
    let ref_ = match rest.first() {
        Some(s) => s.as_str(),
        None => { eprintln!("usage: inbox archive <ref>"); return 1; }
    };
    let (uuid, _rec) = match resolve_ref(ref_, &dirs.inbox_heki) {
        Some(x) => x,
        None => { eprintln!("inbox: no item with ref {}", ref_); return 2; }
    };
    if let Err(e) = heki::delete(&dirs.inbox_heki, &uuid) {
        eprintln!("inbox: heki delete failed: {}", e);
        return 3;
    }
    let subject = format!("inbox({}): drop", ref_);
    durability_dance(dirs, &subject);
    println!("archived {}", ref_);
    0
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Resolve `iN` → (uuid, record). Mirrors Item.GetByRef.
fn resolve_ref(ref_: &str, path: &str) -> Option<(String, heki::Record)> {
    let store = heki::read(path).ok()?;
    for (id, rec) in &store {
        if heki_query::field_to_string(rec.get("ref")) == ref_ {
            return Some((id.clone(), rec.clone()));
        }
    }
    None
}

fn commit_subject(ref_: &str, body: &str) -> String {
    let head: String = body.chars().take(60).collect();
    let head = head.replace('\n', " ");
    format!("inbox({}): {}", ref_, head)
}

// ---------------------------------------------------------------------------
// Durability — CommitLocal + PushToMain (i106 :git adapter, until lands)
// ---------------------------------------------------------------------------

fn durability_dance(dirs: &Dirs, subject: &str) {
    let repo_root = match dirs.repo_root.as_deref() {
        Some(r) => r,
        None => return, // no repo (e.g. HECKS_INFO test seed) — skip silently
    };
    if !Path::new(&format!("{}/.git", repo_root)).exists() {
        return;
    }
    // Step 1 — CommitLocal.
    let staged = Command::new("git")
        .args(["-C", repo_root, "add", &dirs.inbox_relpath])
        .status();
    let staged_ok = matches!(staged, Ok(s) if s.success());
    if !staged_ok { return; }
    let committed = Command::new("git")
        .args(["-C", repo_root, "commit", "-q", "-m", subject])
        .status();
    let committed_ok = matches!(committed, Ok(s) if s.success());
    if !committed_ok {
        eprintln!("warning: heki updated but git commit failed for {}", subject);
        eprintln!("         stage the file manually to preserve the filing");
        return;
    }

    // Step 2 — PushToMain via a temp worktree of origin/main.
    push_to_main(repo_root, &dirs.inbox_relpath, &dirs.inbox_heki, subject);
}

fn push_to_main(repo_root: &str, relpath: &str, source_heki: &str, subject: &str) {
    let tmp_wt = match make_temp_dir() {
        Some(p) => p,
        None => {
            eprintln!("warning: {} push to main skipped (mktemp failed) ; filing is durable on current branch only", subject);
            return;
        }
    };
    let fetched = Command::new("git")
        .args(["-C", repo_root, "fetch", "origin", "main", "--quiet"])
        .status();
    if !matches!(fetched, Ok(s) if s.success()) {
        eprintln!("warning: {} push to main skipped (fetch failed) ; filing is durable on current branch only", subject);
        let _ = std::fs::remove_dir_all(&tmp_wt);
        return;
    }
    let added = Command::new("git")
        .args(["-C", repo_root, "worktree", "add", "--detach", "--quiet",
               &tmp_wt, "origin/main"])
        .status();
    if !matches!(added, Ok(s) if s.success()) {
        eprintln!("warning: {} push to main skipped (worktree setup failed) ; filing is durable on current branch only", subject);
        let _ = std::fs::remove_dir_all(&tmp_wt);
        return;
    }

    let target = format!("{}/{}", tmp_wt, relpath);
    if let Err(e) = std::fs::copy(source_heki, &target) {
        eprintln!("warning: {} push to main failed (copy: {}) ; filing is durable on current branch only", subject, e);
        let _ = Command::new("git")
            .args(["-C", repo_root, "worktree", "remove", "--force", &tmp_wt])
            .status();
        return;
    }

    let mut ok = true;
    let r = Command::new("git").args(["-C", &tmp_wt, "add", relpath]).status();
    ok = ok && matches!(r, Ok(s) if s.success());
    if ok {
        let r = Command::new("git").args(["-C", &tmp_wt, "commit", "-q", "-m", subject]).status();
        ok = ok && matches!(r, Ok(s) if s.success());
    }
    if ok {
        let r = Command::new("git").args(["-C", &tmp_wt, "push", "--quiet", "origin", "HEAD:main"]).status();
        ok = ok && matches!(r, Ok(s) if s.success());
    }
    if !ok {
        eprintln!("warning: {} push to main failed ; filing is durable on current branch only", subject);
    }

    let _ = Command::new("git")
        .args(["-C", repo_root, "worktree", "remove", "--force", &tmp_wt])
        .status();
}

/// Tiny `mktemp -d` replacement using SystemTime entropy. Avoids the
/// platform-specific dependency surface for a single call site.
fn make_temp_dir() -> Option<String> {
    let base = std::env::temp_dir();
    let nanos = std::time::SystemTime::now()
        .duration_since(std::time::SystemTime::UNIX_EPOCH)
        .ok()?
        .as_nanos();
    let pid = std::process::id();
    let dir = base.join(format!("hecks-inbox-push-{}-{}", pid, nanos));
    std::fs::create_dir_all(&dir).ok()?;
    Some(dir.to_string_lossy().into_owned())
}
