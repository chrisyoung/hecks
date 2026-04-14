//! Lazy Runtime — index everything at boot, project on demand
//!
//! Scans the filesystem for .bluebook files, builds a lightweight index,
//! and only compiles/projects a domain when something needs it.
//!
//! Memory tiers:
//!   Resident — always in memory (governance)
//!   Cached   — recently projected, LRU eviction
//!   Indexed  — known path, not loaded
//!
//! Usage:
//!   let mut lr = LazyRuntime::boot("hecks_conception");
//!   lr.dispatch("Law", "Enact", attrs);  // projects Law on first access

use crate::parser;
use crate::runtime::{Runtime, Value};
use std::collections::HashMap;
use std::fs;
use std::path::Path;

const MAX_CACHED: usize = 20;

/// A domain entry in the index — lightweight, no parsing done.
#[derive(Debug)]
pub struct DomainEntry {
    pub name: String,
    pub path: String,
    pub tier: Tier,
    pub access_count: usize,
}

#[derive(Debug, PartialEq)]
pub enum Tier {
    Indexed,
    Cached,
    Resident,
}

pub struct LazyRuntime {
    pub name: String,
    pub index: HashMap<String, DomainEntry>,
    pub runtimes: HashMap<String, Runtime>,
    pub event_log: Vec<super::multi_domain::DomainEvent>,
    pub cross_policies: Vec<super::multi_domain::CrossDomainPolicy>,
}

impl LazyRuntime {
    /// Boot: scan filesystem, build index, project only resident domains.
    pub fn boot(project_dir: &str) -> Result<Self, String> {
        let project = Path::new(project_dir);
        let mut index = HashMap::new();
        let mut runtimes = HashMap::new();
        let mut cross_policies = Vec::new();

        // Scan for all bluebooks
        let bluebook_files = discover_bluebooks(project);

        // Quick-parse each to get name and counts (no full projection)
        for file in &bluebook_files {
            let source = match fs::read_to_string(file) {
                Ok(s) => s,
                Err(_) => continue,
            };
            let domain = parser::parse(&source);
            let name = domain.name.clone();

            // Collect cross-domain policies
            for policy in &domain.policies {
                if let Some(ref target) = policy.target_domain {
                    cross_policies.push(super::multi_domain::CrossDomainPolicy {
                        source_domain: name.clone(),
                        event_name: policy.on_event.clone(),
                        target_domain: target.clone(),
                        target_command: policy.trigger_command.clone(),
                    });
                }
            }

            // Determine if this is governance (resident) or indexed
            let is_governance = file.contains("governance/");
            let tier = if is_governance { Tier::Resident } else { Tier::Indexed };

            // If resident, project immediately
            if is_governance {
                let fixtures = domain.fixtures.clone();
                let mut rt = Runtime::boot(domain);
                super::multi_domain::seed_fixtures(&mut rt, &fixtures);
                runtimes.insert(name.clone(), rt);
            }

            index.insert(name.clone(), DomainEntry {
                name,
                path: file.clone(),
                tier,
                access_count: 0,
            });
        }

        let rt_name = project.file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("unknown")
            .to_string();

        Ok(LazyRuntime {
            name: rt_name,
            index,
            runtimes,
            event_log: Vec::new(),
            cross_policies,
        })
    }

    /// Ensure a domain is projected. Returns true if it was already cached.
    pub fn ensure_projected(&mut self, domain_name: &str) -> Result<bool, String> {
        if self.runtimes.contains_key(domain_name) {
            // Already projected — update access
            if let Some(entry) = self.index.get_mut(domain_name) {
                entry.access_count += 1;
            }
            return Ok(true);
        }

        // Need to project
        let path = self.index.get(domain_name)
            .map(|e| e.path.clone())
            .ok_or_else(|| format!("unknown domain: {}", domain_name))?;

        let source = fs::read_to_string(&path)
            .map_err(|e| format!("cannot read {}: {}", path, e))?;
        let domain = parser::parse(&source);
        let fixtures = domain.fixtures.clone();
        let mut rt = Runtime::boot(domain);
        super::multi_domain::seed_fixtures(&mut rt, &fixtures);

        self.runtimes.insert(domain_name.to_string(), rt);

        if let Some(entry) = self.index.get_mut(domain_name) {
            entry.tier = Tier::Cached;
            entry.access_count += 1;
        }

        // Evict if over capacity
        self.maybe_evict();

        Ok(false)
    }

    /// Dispatch a command — projects the domain on demand if needed.
    pub fn dispatch(
        &mut self,
        domain_name: &str,
        command_name: &str,
        attrs: HashMap<String, Value>,
    ) -> Result<(), String> {
        self.ensure_projected(domain_name)?;

        let rt = self.runtimes.get_mut(domain_name)
            .ok_or_else(|| format!("domain not projected: {}", domain_name))?;

        let result = rt.dispatch(command_name, attrs)
            .map_err(|e| format!("{}", e))?;

        // Log event
        if let Some(ref event) = result.event {
            let seq = self.event_log.len();
            self.event_log.push(super::multi_domain::DomainEvent {
                domain: domain_name.to_string(),
                event_name: event.name.clone(),
                aggregate: result.aggregate_type.clone(),
                aggregate_id: result.aggregate_id.clone(),
                sequence: seq,
            });

            // Cross-domain policies
            let triggers: Vec<_> = self.cross_policies.iter()
                .filter(|p| p.source_domain == domain_name && p.event_name == event.name)
                .map(|p| (p.target_domain.clone(), p.target_command.clone()))
                .collect();

            for (target_domain, target_command) in triggers {
                let _ = self.ensure_projected(&target_domain);
                if let Some(target_rt) = self.runtimes.get_mut(&target_domain) {
                    let event_data = event.data.clone();
                    let _ = target_rt.dispatch(&target_command, event_data);
                }
            }
        }

        Ok(())
    }

    /// Stream through all domains — compile one, process, release.
    /// Callback receives (domain_name, &Runtime) for each.
    pub fn stream<F>(&self, mut callback: F) -> usize
    where
        F: FnMut(&str, &Runtime),
    {
        let mut count = 0;
        for entry in self.index.values() {
            let source = match fs::read_to_string(&entry.path) {
                Ok(s) => s,
                Err(_) => continue,
            };
            let domain = parser::parse(&source);
            let fixtures = domain.fixtures.clone();
            let mut rt = Runtime::boot(domain);
            super::multi_domain::seed_fixtures(&mut rt, &fixtures);
            callback(&entry.name, &rt);
            count += 1;
            // rt drops here — memory released
        }
        count
    }

    /// Evict LRU cached domains if over capacity.
    fn maybe_evict(&mut self) {
        let cached_count = self.index.values()
            .filter(|e| e.tier == Tier::Cached)
            .count();

        if cached_count <= MAX_CACHED {
            return;
        }

        // Find LRU cached domain
        let lru = self.index.values()
            .filter(|e| e.tier == Tier::Cached)
            .min_by_key(|e| e.access_count)
            .map(|e| e.name.clone());

        if let Some(name) = lru {
            self.runtimes.remove(&name);
            if let Some(entry) = self.index.get_mut(&name) {
                entry.tier = Tier::Indexed;
            }
        }
    }

    /// Print summary.
    pub fn summary(&self) {
        let resident = self.index.values().filter(|e| e.tier == Tier::Resident).count();
        let cached = self.index.values().filter(|e| e.tier == Tier::Cached).count();
        let indexed = self.index.values().filter(|e| e.tier == Tier::Indexed).count();
        let total_aggs: usize = self.runtimes.values()
            .map(|rt| rt.domain.aggregates.len())
            .sum();

        println!("  {} domains indexed ({} resident, {} cached, {} on disk)",
            self.index.len(), resident, cached, indexed);
        println!("  {} domains projected in memory ({} aggregates)",
            self.runtimes.len(), total_aggs);
    }
}

/// Make seed_fixtures public for use by both multi_domain and lazy_runtime.
/// (Re-exported from multi_domain)

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
