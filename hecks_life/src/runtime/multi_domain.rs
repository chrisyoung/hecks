//! Multi-domain runtime — boots an entire hecksagon from Bluebooks
//!
//! Reads hecksagon.hec, discovers domain bluebooks, boots each as a
//! Runtime, wires cross-domain policies, seeds fixtures as initial state.
//!
//! Usage:
//!   let conception = MultiDomainRuntime::boot("hecks_conception");
//!   conception.dispatch("Law", "Enact", attrs);

use crate::parser;
use crate::runtime::{Runtime, Value, Repository};
use std::collections::HashMap;
use std::fs;
use std::path::Path;

pub struct MultiDomainRuntime {
    pub name: String,
    pub domains: HashMap<String, Runtime>,
    pub cross_policies: Vec<CrossDomainPolicy>,
    pub event_log: Vec<DomainEvent>,
}

pub struct CrossDomainPolicy {
    pub source_domain: String,
    pub event_name: String,
    pub target_domain: String,
    pub target_command: String,
}

#[derive(Debug, Clone)]
pub struct DomainEvent {
    pub domain: String,
    pub event_name: String,
    pub aggregate: String,
    pub aggregate_id: String,
    pub sequence: usize,
}

impl MultiDomainRuntime {
    /// Boot an entire hecksagon from a directory.
    /// Discovers .bluebook files, parses each, boots runtimes, wires policies.
    pub fn boot(project_dir: &str) -> Result<Self, String> {
        let project = Path::new(project_dir);

        // Find all .bluebook files in the project
        let bluebook_files = discover_bluebooks(project);
        if bluebook_files.is_empty() {
            return Err(format!("no .bluebook files found in {}", project_dir));
        }

        let mut domains = HashMap::new();
        let mut cross_policies = Vec::new();

        // Parse and boot each domain
        for file in &bluebook_files {
            let source = fs::read_to_string(file)
                .map_err(|e| format!("cannot read {}: {}", file, e))?;
            let domain_ir = parser::parse(&source);
            let domain_name = domain_ir.name.clone();

            // Collect cross-domain policies before booting
            for policy in &domain_ir.policies {
                if let Some(ref target) = policy.target_domain {
                    cross_policies.push(CrossDomainPolicy {
                        source_domain: domain_name.clone(),
                        event_name: policy.on_event.clone(),
                        target_domain: target.clone(),
                        target_command: policy.trigger_command.clone(),
                    });
                }
            }

            // Seed fixtures after boot
            let fixtures = domain_ir.fixtures.clone();
            let mut rt = Runtime::boot(domain_ir);
            seed_fixtures_from(&mut rt, &fixtures);

            domains.insert(domain_name, rt);
        }

        let name = project.file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("unknown")
            .to_string();

        Ok(MultiDomainRuntime {
            name,
            domains,
            cross_policies,
            event_log: Vec::new(),
        })
    }

    /// Dispatch a command to a specific domain.
    pub fn dispatch(
        &mut self,
        domain_name: &str,
        command_name: &str,
        attrs: HashMap<String, Value>,
    ) -> Result<(), String> {
        let rt = self.domains.get_mut(domain_name)
            .ok_or_else(|| format!("unknown domain: {}", domain_name))?;

        let result = rt.dispatch(command_name, attrs)
            .map_err(|e| format!("{}", e))?;

        // Log the event
        if let Some(ref event) = result.event {
            let seq = self.event_log.len();
            let domain_event = DomainEvent {
                domain: domain_name.to_string(),
                event_name: event.name.clone(),
                aggregate: result.aggregate_type.clone(),
                aggregate_id: result.aggregate_id.clone(),
                sequence: seq,
            };
            self.event_log.push(domain_event);

            // Fire cross-domain policies
            let triggers: Vec<_> = self.cross_policies.iter()
                .filter(|p| p.source_domain == domain_name && p.event_name == event.name)
                .map(|p| (p.target_domain.clone(), p.target_command.clone()))
                .collect();

            for (target_domain, target_command) in triggers {
                if let Some(target_rt) = self.domains.get_mut(&target_domain) {
                    let event_data = event.data.clone();
                    let _ = target_rt.dispatch(&target_command, event_data);
                }
            }
        }

        Ok(())
    }

    /// Get a domain runtime by name.
    pub fn domain(&self, name: &str) -> Option<&Runtime> {
        self.domains.get(name)
    }

    /// Print boot summary.
    pub fn summary(&self) {
        let total_aggs: usize = self.domains.values()
            .map(|rt| rt.domain.aggregates.len())
            .sum();
        let total_cmds: usize = self.domains.values()
            .map(|rt| rt.domain.aggregates.iter().map(|a| a.commands.len()).sum::<usize>())
            .sum();
        let total_fixtures: usize = self.domains.values()
            .map(|rt| rt.domain.fixtures.len())
            .sum();

        println!("  {} domains, {} aggregates, {} commands, {} fixtures, {} cross-domain policies",
            self.domains.len(), total_aggs, total_cmds, total_fixtures, self.cross_policies.len());
    }
}

/// Discover all .bluebook files in a directory tree.
fn discover_bluebooks(dir: &Path) -> Vec<String> {
    let mut files = Vec::new();
    walk_for_bluebooks(dir, &mut files);
    files.sort();
    files
}

fn walk_for_bluebooks(dir: &Path, files: &mut Vec<String>) {
    if let Ok(entries) = fs::read_dir(dir) {
        for entry in entries.filter_map(|e| e.ok()) {
            let path = entry.path();
            if path.is_dir() {
                // Skip node_modules, .git, target
                let name = path.file_name().and_then(|n| n.to_str()).unwrap_or("");
                if name == "node_modules" || name == ".git" || name == "target" {
                    continue;
                }
                walk_for_bluebooks(&path, files);
            } else if path.extension().map_or(false, |e| e == "bluebook") {
                files.push(path.to_string_lossy().into_owned());
            }
        }
    }
}

/// Seed a runtime's repositories from fixture data.
/// Collects dispatch calls first (to avoid borrow conflicts), then executes.
fn seed_fixtures_from(rt: &mut Runtime, fixtures: &[crate::ir::Fixture]) {
    // Phase 1: collect (command_name, attrs) pairs without borrowing rt mutably
    let dispatches: Vec<(String, HashMap<String, Value>)> = fixtures.iter()
        .filter_map(|fixture| {
            let agg = rt.domain.aggregates.iter()
                .find(|a| a.name == fixture.aggregate_name)?;
            let create_cmd = agg.commands.iter()
                .find(|c| !c.references.iter().any(|r| r.target == agg.name))?;

            let mut attrs: HashMap<String, Value> = HashMap::new();
            for (key, val) in &fixture.attributes {
                let value = if let Ok(n) = val.parse::<i64>() {
                    Value::Int(n)
                } else if val == "true" || val == "false" {
                    Value::Bool(val == "true")
                } else {
                    Value::Str(val.trim_matches('"').to_string())
                };
                attrs.insert(key.clone(), value);
            }

            Some((create_cmd.name.clone(), attrs))
        })
        .collect();

    // Phase 2: dispatch all collected commands
    for (cmd_name, attrs) in dispatches {
        let _ = rt.dispatch(&cmd_name, attrs);
    }
}
