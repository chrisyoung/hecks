//! Action Stack — deterministic governance foundation
//!
//! Manages .action_stack file: push/pop actions, check depth.
//! The gate checks this before every command. Empty stack = refused.
//!
//! Usage:
//!   hecks-life action init    <project-dir>    Create stack + session action
//!   hecks-life action push    <action-path>    Push sub-action
//!   hecks-life action pop                      Pop completed action
//!   hecks-life action check                    Exit 0 if non-empty, 1 if empty
//!   hecks-life action current                  Print current action path
//!   hecks-life action depth                    Print stack depth
//!   hecks-life action list                     Print full stack

use std::fs;
use std::path::Path;

const STACK_FILE: &str = ".action_stack";
const ACTIONS_DIR: &str = "actions";

/// Read the action stack from the project directory.
/// Returns a Vec of action paths (bottom = session, top = current).
pub fn read_stack(project_dir: &str) -> Vec<String> {
    let path = Path::new(project_dir).join(STACK_FILE);
    match fs::read_to_string(&path) {
        Ok(contents) => contents
            .lines()
            .filter(|l| !l.trim().is_empty())
            .map(|l| l.trim().to_string())
            .collect(),
        Err(_) => Vec::new(),
    }
}

/// Write the stack back to disk.
fn write_stack(project_dir: &str, stack: &[String]) {
    let path = Path::new(project_dir).join(STACK_FILE);
    let contents = stack.join("\n") + "\n";
    if let Err(e) = fs::write(&path, contents) {
        eprintln!("action_stack: cannot write {}: {}", path.display(), e);
    }
}

/// Check if the stack is non-empty. Returns true if there's an active action.
pub fn check(project_dir: &str) -> bool {
    !read_stack(project_dir).is_empty()
}

/// Get the current (top) action path, or None if empty.
pub fn current(project_dir: &str) -> Option<String> {
    read_stack(project_dir).last().cloned()
}

/// Get the stack depth.
pub fn depth(project_dir: &str) -> usize {
    read_stack(project_dir).len()
}

/// Push an action onto the stack.
pub fn push(project_dir: &str, action_path: &str) {
    let mut stack = read_stack(project_dir);
    stack.push(action_path.to_string());
    write_stack(project_dir, &stack);
}

/// Pop the top action off the stack. Returns the popped path.
pub fn pop(project_dir: &str) -> Option<String> {
    let mut stack = read_stack(project_dir);
    let popped = stack.pop();
    write_stack(project_dir, &stack);
    popped
}

/// Initialize the stack with a session action.
/// Creates the actions/ dir if needed, generates a session bluebook,
/// and pushes it as the first entry.
pub fn init(project_dir: &str, engine: &str) -> String {
    let actions_dir = Path::new(project_dir).join(ACTIONS_DIR);
    if !actions_dir.is_dir() {
        let _ = fs::create_dir_all(&actions_dir);
    }

    // Generate session action bluebook
    let timestamp = chrono_timestamp();
    let session_id = format!("session_{}", timestamp);
    let filename = format!("{}.bluebook", session_id);
    let action_path = format!("{}/{}", ACTIONS_DIR, filename);
    let full_path = Path::new(project_dir).join(&action_path);

    let content = format!(
        r#"Hecks.bluebook "{}", version: "2026.04.15.1" do
  vision "Auto-generated session action — the primordial action created by the bootloader"
  category "session"

  aggregate "Session", "This session" do
    String :session_id
    String :engine
    String :started_at
    String :status

    Start do
      role "Bootloader"
      emits "SessionStarted"
      then_set :session_id, to: "{}"
      then_set :engine, to: "{}"
      then_set :status, to: "active"
    end

    lifecycle :status, default: "pending" do
      transition "Start" => "active"
    end
  end

  fixture "Session", session_id: "{}", engine: "{}", started_at: "{}", status: "active"
end
"#,
        session_id, session_id, engine, session_id, engine, timestamp
    );

    if let Err(e) = fs::write(&full_path, &content) {
        eprintln!("action_stack: cannot write session action: {}", e);
    }

    // Clear and init stack with session action
    write_stack(project_dir, &[action_path.clone()]);

    action_path
}

/// Find the project dir from action command args.
/// Convention: last argument that is a directory is the project dir.
fn resolve_action_dir(args: &[String]) -> String {
    for arg in args.iter().rev() {
        if arg.starts_with('-') { continue; }
        if std::path::Path::new(arg).is_dir() {
            return arg.to_string();
        }
    }
    ".".to_string()
}

/// Run the action subcommand from CLI args.
pub fn run_action_command(args: &[String], _fallback_dir: &str) {
    if args.len() < 3 {
        eprintln!("Usage: hecks-life action <init|push|pop|check|current|depth|list> <project-dir> [args]");
        std::process::exit(1);
    }

    let sub = args[2].as_str();
    let project_dir = resolve_action_dir(args);

    match sub {
        "init" => {
            let engine = args.iter()
                .position(|a| a == "--engine")
                .and_then(|i| args.get(i + 1))
                .map(|s| s.as_str())
                .unwrap_or("claude");
            let path = init(&project_dir, engine);
            println!("  action stack initialized: {}", path);
        }
        "push" => {
            // Find the action path — first non-dir, non-flag arg after "push"
            let action_path = args.iter().skip(3)
                .find(|a| !a.starts_with('-') && !std::path::Path::new(a.as_str()).is_dir())
                .cloned();
            match action_path {
                Some(path) => {
                    push(&project_dir, &path);
                    println!("  pushed: {} (depth: {})", path, depth(&project_dir));
                }
                None => {
                    eprintln!("Usage: hecks-life action push <action-path> <project-dir>");
                    std::process::exit(1);
                }
            }
        }
        "pop" => {
            match pop(&project_dir) {
                Some(path) => println!("  popped: {} (depth: {})", path, depth(&project_dir)),
                None => {
                    eprintln!("  action stack is empty — nothing to pop");
                    std::process::exit(1);
                }
            }
        }
        "check" => {
            if check(&project_dir) {
                if !args.iter().any(|a| a == "--quiet") {
                    println!("  action stack: depth {}", depth(&project_dir));
                }
            } else {
                eprintln!("BLOCKED: No active action. Run: hecks-life action init");
                std::process::exit(1);
            }
        }
        "current" => {
            match current(&project_dir) {
                Some(path) => println!("{}", path),
                None => {
                    eprintln!("  no active action");
                    std::process::exit(1);
                }
            }
        }
        "depth" => {
            println!("{}", depth(&project_dir));
        }
        "list" => {
            let stack = read_stack(&project_dir);
            if stack.is_empty() {
                println!("  (empty)");
            } else {
                for (i, entry) in stack.iter().enumerate() {
                    let marker = if i == stack.len() - 1 { "→" } else { " " };
                    println!("  {} [{}] {}", marker, i, entry);
                }
            }
        }
        _ => {
            eprintln!("Unknown action command: {}", sub);
            eprintln!("Available: init, push, pop, check, current, depth, list");
            std::process::exit(1);
        }
    }
}

/// Generate a timestamp string for session IDs.
fn chrono_timestamp() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};
    let secs = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    // Format as YYYY_MM_DD_HHMMSS (approximate — no chrono crate needed)
    let days = secs / 86400;
    let years = 1970 + days / 365; // approximate
    let remaining = secs % 86400;
    let hours = remaining / 3600;
    let mins = (remaining % 3600) / 60;
    let s = remaining % 60;
    format!("{}_{:02}_{:02}_{:02}{:02}{:02}", years, (days % 365) / 30 + 1, (days % 30) + 1, hours, mins, s)
}
