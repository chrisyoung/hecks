// PRD 10 (ADR 0030 Slice 2) — the Rust side of `Binding` lowering, a
// structural mirror of `Hecksagain::Bluebook::Expression::BindingLowering`
// (lib/hecksagain/bluebook/expression/binding_lowering.rb), read
// directly. See that file's own header for the full argument; the short
// version: canonical `Binding` (`{key, value}`) resolves at real
// dispatch time through procedural branching hidden inside
// `PolicyInterpreter#trigger_args`/`SagaInterpreter#dispatch_args`, with
// zero Rust representation at all — this gives that resolution strategy
// a NAME as data (`Literal`/`Reference`), reusing `expr::Value` for a
// literal's payload rather than inventing a second value type.
//
// INTERPRETATION ONLY — `Source`/`ExecutableBinding` themselves are
// GENERATED (`../mod.rs`, from `bin/project_binding_shape`, ground
// truth `Hecksagain::Bluebook::Expression::BindingShape`), closing the
// "two hand-authored mirrors" gap PRD 10 originally shipped with and
// flagged honestly (ADR 0030's own Slice-2 stop-condition check). What
// stays hand-written here, deliberately, is only `lower`/`resolve` —
// the same "generate structure, handwrite meaning" boundary
// `expression_operators/*.rs` already draws (PRD 09).
//
// WHAT THIS FILE DELIBERATELY DOES NOT KNOW — same as the Ruby side: no
// concept of "correlation head" or "saga memory." `lower`/`resolve`
// take an ordered `priority: &[String]` of named source buckets as a
// plain argument; assembling those buckets correctly is a future
// `Reaction`/`ReactionContext` (ADR 0030 Slice 3) caller's job.

use super::{ExecutableBinding, Source};
use crate::kernel::expr::Value;
use std::collections::HashMap;

/// A source bucket, keyed by field name — `sources["payload"]["account_id"]`
/// is the shape a real assembled context would have.
pub type SourceBucket = HashMap<String, Value>;
pub type Sources = HashMap<String, SourceBucket>;

/// `binding` is a `(key, value)` pair — the same shape `with_spec`'s own
/// real elements have (`policy.rb`/`process_manager.rb`, read directly:
/// `with_spec.map { |key, value| ... }`). `value` being a `Value::Str`
/// that names a REFERENCE (Ruby's `value.is_a?(Symbol)`) versus a
/// genuine literal is the one thing the caller must already know —
/// `is_reference` makes that call explicit here rather than guessing
/// from the `Value` shape alone, since a literal string and a symbol
/// name are indistinguishable once both are plain Rust `String`s.
pub fn lower(key: &str, value: Value, is_reference: bool, priority: &[String]) -> ExecutableBinding {
    let source = if is_reference {
        let name = match &value {
            Value::Str(s) => s.clone(),
            other => panic!("lower called with is_reference: true but a non-string value {other:?} — a caller bug, not a domain refusal"),
        };
        Source::Reference { name, priority: priority.to_vec() }
    } else {
        Source::Literal { value }
    };

    ExecutableBinding { destination: key.to_string(), source }
}

/// Resolves one executable binding against a real `sources` map,
/// returning `(destination, value)` — the same pair shape
/// `trigger_args`/`dispatch_args`'s own `to_h` block produces.
pub fn resolve(binding: &ExecutableBinding, sources: &Sources) -> (String, Value) {
    let value = match &binding.source {
        Source::Literal { value } => value.clone(),
        Source::Reference { name, priority } => resolve_reference(name, priority, sources),
    };
    (binding.destination.clone(), value)
}

/// First bucket in `priority` that actually HOLDS `name` wins. The LAST
/// bucket in `priority` is the unconditional fallback if none matched —
/// mirroring `dispatch_args`'s own final `else instance[:memory][value]`,
/// a plain Hash `#[]` miss answering `nil` there, not a refusal — so a
/// wholly absent name resolves to `Value::Nil` here rather than
/// panicking.
fn resolve_reference(name: &str, priority: &[String], sources: &Sources) -> Value {
    for bucket_name in priority {
        if let Some(bucket) = sources.get(bucket_name) {
            if let Some(v) = bucket.get(name) {
                return v.clone();
            }
        }
    }

    priority
        .last()
        .and_then(|last| sources.get(last))
        .and_then(|bucket| bucket.get(name))
        .cloned()
        .unwrap_or(Value::Nil)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn bucket(pairs: &[(&str, Value)]) -> SourceBucket {
        pairs.iter().map(|(k, v)| (k.to_string(), v.clone())).collect()
    }

    #[test]
    fn resolves_a_literal_to_itself_untouched_by_any_source() {
        let b = lower("status", Value::Str("frozen".to_string()), false, &[]);
        let (dest, v) = resolve(&b, &Sources::new());

        assert_eq!(dest, "status");
        assert_eq!(v, Value::Str("frozen".to_string()));
    }

    // SagaInterpreter#dispatch_args's own real branch order — correlation
    // head first, then payload, then memory. A binding whose name IS the
    // correlation head must win from the correlation bucket even when the
    // SAME name also exists in payload/memory.
    #[test]
    fn prefers_correlation_over_payload_over_memory_in_that_exact_order() {
        let priority = vec!["correlation".to_string(), "payload".to_string(), "memory".to_string()];
        let b = lower("account", Value::Str("account_id".to_string()), true, &priority);

        let mut sources = Sources::new();
        sources.insert("correlation".to_string(), bucket(&[("account_id", Value::Str("from-correlation".to_string()))]));
        sources.insert("payload".to_string(), bucket(&[("account_id", Value::Str("from-payload".to_string()))]));
        sources.insert("memory".to_string(), bucket(&[("account_id", Value::Str("from-memory".to_string()))]));

        let (_, v) = resolve(&b, &sources);
        assert_eq!(v, Value::Str("from-correlation".to_string()));
    }

    #[test]
    fn falls_all_the_way_through_to_nil_when_nothing_holds_the_name() {
        let priority = vec!["correlation".to_string(), "payload".to_string(), "memory".to_string()];
        let b = lower("missing", Value::Str("nowhere".to_string()), true, &priority);

        let mut sources = Sources::new();
        sources.insert("correlation".to_string(), SourceBucket::new());
        sources.insert("payload".to_string(), SourceBucket::new());
        sources.insert("memory".to_string(), SourceBucket::new());

        let (_, v) = resolve(&b, &sources);
        assert_eq!(v, Value::Nil);
    }
}
