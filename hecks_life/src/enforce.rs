//! Enforce — pre-commit law enforcement
//!
//! Reads git diff, checks staged files against laws, reports violations.
//! Called by the pre-commit hook: `hecks-life enforce --diff <conception-dir>`
//!
//! Exit 0 = clear (commit allowed)
//! Exit 1 = blocked (commit refused)

use std::process::Command;
use std::path::Path;

/// Run enforcement against the staged git diff.
pub fn run_diff(project_dir: &str) -> bool {
    let staged = get_staged_files();
    if staged.is_empty() {
        println!("  ❄ enforce: no staged files");
        return true;
    }

    let mut violations: Vec<(String, String, String)> = Vec::new(); // (file, law, detail)
    let mut warnings: Vec<(String, String, String)> = Vec::new();
    let mut files_checked = 0;

    for file in &staged {
        files_checked += 1;

        // Law: FileSizeLimit — code files must be under 200 lines
        if is_code_file(file) && Path::new(file).exists() {
            if let Some(lines) = count_code_lines(file) {
                if lines > 200 {
                    violations.push((
                        file.clone(),
                        "FileSizeLimit".into(),
                        format!("{} code lines (limit: 200)", lines),
                    ));
                }
            }
        }

        // Law: BluebookOnly — scripts in conception need a catalog bluebook
        if is_conception_script(file, project_dir) {
            let script_name = Path::new(file)
                .file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or("");
            let catalog_path = Path::new(project_dir)
                .join("catalog")
                .join(format!("{}.bluebook", script_name));
            if !catalog_path.exists() {
                violations.push((
                    file.clone(),
                    "BluebookOnly".into(),
                    "script has no corresponding catalog bluebook".into(),
                ));
            }
        }

        // Law: FixturesRequired — bluebook files must have fixtures
        if file.ends_with(".bluebook") && Path::new(file).exists() {
            if let Ok(contents) = std::fs::read_to_string(file) {
                let has_fixtures = contents.lines().any(|l| l.trim_start().starts_with("fixture "));
                if !has_fixtures {
                    warnings.push((
                        file.clone(),
                        "FixturesRequired".into(),
                        "bluebook has no fixture lines".into(),
                    ));
                }
            }
        }

        // Law: ActionFirst — at least one action bluebook should be staged
        // (checked after the loop)
    }

    // Law: ActionFirst — check if any action bluebook is staged
    let has_action = staged.iter().any(|f| f.contains("actions/"));
    if !has_action {
        // Check if the action stack has an entry
        let stack_has_entry = crate::action_stack::check(project_dir);
        if !stack_has_entry {
            violations.push((
                "(commit)".into(),
                "ActionFirst".into(),
                "no action bluebook staged and action stack is empty".into(),
            ));
        }
    }

    // Report
    let total_violations = violations.len();
    let total_warnings = warnings.len();

    if total_violations == 0 && total_warnings == 0 {
        println!("  ❄ enforce: {} files checked, all clear", files_checked);
        return true;
    }

    if total_warnings > 0 {
        println!("  ❄ enforce: {} warning(s):", total_warnings);
        for (file, law, detail) in &warnings {
            println!("    ⚠ {} — {} ({})", law, detail, file);
        }
    }

    if total_violations > 0 {
        println!("  ❄ BLOCKED: {} violation(s):", total_violations);
        for (file, law, detail) in &violations {
            println!("    🔴 {} — {} ({})", law, detail, file);
        }
        println!();
        println!("  Fix violations and re-stage, or back out the offending changes.");
        return false;
    }

    true
}

/// Run enforcement against the full codebase (not just diff).
pub fn run_full(project_dir: &str) -> bool {
    // TODO: implement full sweep
    println!("  ❄ enforce: full sweep not yet implemented, use --diff");
    true
}

/// Get list of staged files from git.
fn get_staged_files() -> Vec<String> {
    let output = Command::new("git")
        .args(["diff", "--cached", "--name-only"])
        .output();

    match output {
        Ok(out) => {
            String::from_utf8_lossy(&out.stdout)
                .lines()
                .filter(|l| !l.trim().is_empty())
                .map(|l| l.to_string())
                .collect()
        }
        Err(_) => Vec::new(),
    }
}

/// Is this a code file that should be checked for size?
fn is_code_file(path: &str) -> bool {
    path.ends_with(".rb") || path.ends_with(".js")
}

/// Is this a script in the conception directory without a bluebook?
fn is_conception_script(path: &str, project_dir: &str) -> bool {
    let in_conception = path.starts_with(project_dir) ||
        path.contains("hecks_conception");
    let is_script = path.ends_with(".py") || path.ends_with(".sh") ||
        (path.ends_with(".js") && !path.ends_with(".bluebook"));
    in_conception && is_script
}

/// Count non-comment, non-blank lines in a file.
fn count_code_lines(path: &str) -> Option<usize> {
    std::fs::read_to_string(path).ok().map(|contents| {
        contents.lines()
            .filter(|l| {
                let trimmed = l.trim();
                !trimmed.is_empty() && !trimmed.starts_with('#') && !trimmed.starts_with("//")
            })
            .count()
    })
}

/// CLI entry point for enforce commands.
pub fn run_command(args: &[String], project_dir: &str) {
    let is_diff = args.iter().any(|a| a == "--diff");

    let passed = if is_diff {
        run_diff(project_dir)
    } else {
        run_full(project_dir)
    };

    if !passed {
        std::process::exit(1);
    }
}
