//! Two functions ported out of `rust/project/mutations.rb` early — used by
//! BOTH `types.rb`'s `emit_record` and `json_codec.rb`'s `emit_to_json_flat`
//! /`emit_from_json_state`, so they live here rather than being duplicated.
//! `mutations.rb` itself (the command-mutation codegen this stage does not
//! port — see the report) is NOT ported; only these two self-contained
//! predicates, whose only real dependency is `aggregate[:commands]`'s shape
//! as already present in ir.json, moved over.

use crate::json::Json;
use std::collections::HashMap;

/// One `aggregate["projected_fields"]` entry (S12, ADR 0025's `projects`
/// construct) — `AggregateBuilder#projects_impl`'s own three fields,
/// already carried on `ir.json` by the SAME export the Ruby interpreter
/// reads at runtime (`hexagon.rb`); this crate just parses it. Shared
/// between `types.rs`'s own struct-field emission, `fielded.rs`'s own
/// `field()` arm, `json_codec.rs`'s own to_json/from_json, and `domain_
/// generator.rs`'s own dispatch-time seed fn, the same reason `attr.rs`'s
/// helpers are shared rather than each caller re-parsing the JSON node.
pub struct ProjectedField {
    pub name: String,
    pub reference: String,
    pub remote_field: String,
}

pub fn projected_fields(aggregate: &Json) -> Vec<ProjectedField> {
    aggregate
        .get("projected_fields")
        .map(Json::each)
        .unwrap_or(&[])
        .iter()
        .map(|f| ProjectedField {
            name: f.get("name").map(Json::to_s).unwrap_or_default(),
            reference: f.get("reference").map(Json::to_s).unwrap_or_default(),
            remote_field: f.get("remote_field").map(Json::to_s).unwrap_or_default(),
        })
        .collect()
}

/// Argument names already claimed by an append (this command's own) — an
/// append's element-field argument is never ALSO eligible to bare-name-
/// match an unrelated owner field that happens to share its name. Shared
/// between `creates_owner` and `mutations.rs#identity_components`, which
/// both need the identical exclusion set for the identical reason.
pub fn append_claimed_names(command: &Json) -> std::collections::HashSet<String> {
    let mut claimed = std::collections::HashSet::new();
    for m in command.get("mutations").map(Json::each).unwrap_or(&[]) {
        if m.get("op").map(Json::to_s).as_deref() != Some("append") {
            continue;
        }
        if let Some(Json::Object(pairs)) = m.get("fields") {
            for (_, wire_value) in pairs {
                let literal = crate::literal::read(wire_value.as_str().unwrap_or(""));
                if let crate::literal::Literal::Symbol(s) = literal {
                    claimed.insert(s);
                }
            }
        }
    }
    claimed
}

/// `creates_owner(aggregate, command, value_objects_by_name)` — REPLACES
/// `command.get("references").is_none()` ALONE (and the coincidental bare-
/// name matching `mutations.rs#identity_components` used to do) as the
/// "does this command build the OWNER record from scratch" test.
///
/// Ported directly from `rust/project/mutations.rb#creates_owner?` — read
/// that function's own header for the full argument: `references.nil?` is
/// honest whenever it's SET (a genuine `reference_to <owner>` really does
/// mean "acts on an existing one"), dishonest only when absent — and even
/// then, the real test is NOT completeness (a creating command's generated
/// struct Option-wraps every scalar field regardless, so an uncovered
/// field just becomes `None` — `Pizzas::Order.CreatePizza`, zero
/// mutations, is the corpus's plainest live proof). The real test: does
/// this command supply — via a `:set` mutation OR a same-named argument
/// `record_fields` (commands.rb) copies straight across with no mutation
/// at all — at least one of the owner's own REQUIRED (non-list, non-
/// optional) fields, excluding any argument already claimed by an append
/// (`append_claimed_names`, above — the same bare-name coincidence this
/// whole fix exists to stop trusting blindly, e.g. `ValueObject.Member`'s
/// own `position` feeding the appended MEMBER's `position`, never
/// `ValueObject`'s own unrelated field of the same name).
pub fn creates_owner(aggregate: &Json, command: &Json, _value_objects_by_name: &HashMap<String, &Json>) -> bool {
    if command.get("references").is_some() {
        return false;
    }

    let attrs = aggregate.get("attributes").map(Json::each).unwrap_or(&[]);
    let owner_fields: std::collections::HashSet<String> = attrs.iter().map(|a| crate::attr::name(a).to_string()).collect();
    let required_fields: std::collections::HashSet<String> =
        attrs.iter().filter(|a| !crate::attr::list(a) && !crate::attr::optional(a)).map(|a| crate::attr::name(a).to_string()).collect();

    let append_claimed = append_claimed_names(command);

    let mut known_writes: std::collections::HashSet<String> = std::collections::HashSet::new();
    for attr in command.get("attributes").map(Json::each).unwrap_or(&[]) {
        let name = crate::attr::name(attr).to_string();
        if owner_fields.contains(&name) && !append_claimed.contains(&name) {
            known_writes.insert(name);
        }
    }
    for m in command.get("mutations").map(Json::each).unwrap_or(&[]) {
        if m.get("op").map(Json::to_s).as_deref() != Some("set") {
            continue;
        }
        let target = m.get("target").map(Json::to_s).unwrap_or_default();
        if owner_fields.contains(&target) {
            known_writes.insert(target);
        }
    }

    required_fields.iter().any(|field| known_writes.contains(field))
}

/// A list-typed aggregate attribute reads `nil` in Ruby, not `[]`, under
/// one precise condition — see `mutations.rb#list_attr_creation_optional?`'s
/// own header for the full argument. Mirrored directly here.
pub fn list_attr_creation_optional(aggregate: &Json, attr_name: &str, value_objects_by_name: &HashMap<String, &Json>) -> bool {
    let commands = aggregate.get("commands").map(Json::each).unwrap_or(&[]);
    commands.iter().any(|command| {
        if !creates_owner(aggregate, command, value_objects_by_name) {
            return false;
        }
        let mutations = command.get("mutations").map(Json::each).unwrap_or(&[]);
        mutations.iter().any(|m| {
            let op = m.get("op").map(Json::to_s).unwrap_or_default();
            let target = m.get("target").map(Json::to_s).unwrap_or_default();
            if op != "set" || target != attr_name {
                return false;
            }
            let source = match m.get("source") {
                Some(s) => s,
                None => return false,
            };
            if source.get("kind").map(Json::to_s).unwrap_or_default() != "argument" {
                return false;
            }
            let source_name = source.get("name").map(Json::to_s).unwrap_or_default();
            let attrs = command.get("attributes").map(Json::each).unwrap_or(&[]);
            match attrs.iter().find(|a| crate::attr::name(a) == source_name) {
                Some(source_attr) => crate::attr::optional(source_attr),
                None => false,
            }
        })
    })
}
