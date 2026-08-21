// ADR 0030 Slice 3 — the Rust side of `Reaction` dispatch-binding
// resolution, a structural mirror of `Hecksagain::Runtime::
// ReactionExecutor#resolve_args` (lib/hecksagain/runtime/
// reaction_executor.rb), read directly. INTERPRETATION ONLY —
// `Reaction`/`Dispatch`/`Bindings` themselves are GENERATED (`../mod.rs`,
// from `bin/project_reaction_shape`, ground truth
// `Hecksagain::PrimalIR::Shape`) — the same "generate structure,
// handwrite meaning" split `kernel/binding/logic.rs` already draws.
//
// CONDITION EVALUATION (`Reaction#evaluate_condition`'s own Rust
// counterpart) IS DELIBERATELY NOT HERE, AND NOT ATTEMPTED YET — a real,
// confirmed architectural finding, not an oversight: `orchestrate.rs`'s
// own real, working reaction engine checks a saga leg's own state guard
// with a PLAIN, DIRECT string comparison (`state != handler.from_state`,
// `orchestrate.rs::advance_saga`, read directly), never through `kernel::
// expr::interpret`/`Fielded` — and `PolicyRule` (`orchestrate.rs`'s own
// struct) carries NO `where`/condition field AT ALL, meaning Rust's real
// reaction engine does not support an arbitrary policy `where` clause
// today, full stop. Every `Fielded` implementor in this crate
// (`rust/src/generated/*.rs`) is a STATICALLY TYPED, per-command
// generated struct — `kernel::expr::interpret` has never needed to
// evaluate an expression against arbitrary, dynamically-shaped runtime
// data (an event's own payload, a saga's own free-form memory Hash) the
// way `PrimalIR::Reaction.condition` would need to. Building that
// generic, dynamic-Fielded machinery is real, substantial, separate
// work with its own design question (does Rust's reaction engine even
// need general `where`-clause support, given it doesn't have any
// today?) — not resolved here, and not guessed at.
//
// WHAT THIS FILE DELIBERATELY DOES NOT KNOW — same boundary
// `kernel/binding/logic.rs`'s own header draws: no concept of how
// `sources` gets assembled (correlation head, saga memory, event
// payload) — that stays a future caller's job, the same as it does on
// the Ruby side.

use super::{Bindings, Dispatch};
use crate::kernel::binding::{resolve, Sources};
use crate::kernel::expr::Value;
use std::collections::HashMap;

/// Mirrors `ReactionExecutor#resolve_args` exactly: resolve ONE
/// `Dispatch`'s own bindings against real `sources`, returning
/// destination => value pairs ready to hand to a command's own dispatch.
///
/// `Bindings::Verbatim` forwards `sources["payload"]` WHOLESALE — the
/// real, distinct default a `policy` with no declared `with:` has
/// (`Dispatch::VERBATIM`'s own Ruby comment, `lib/hecksagain/primal_ir.rb`)
/// — never reducible to an empty bindings list, which resolves to `{}`
/// instead (`Bindings::Explicit(vec![])`, a real, different value).
pub fn resolve_dispatch_bindings(dispatch: &Dispatch, sources: &Sources) -> HashMap<String, Value> {
    match &dispatch.bindings {
        Bindings::Verbatim => sources.get("payload").cloned().unwrap_or_default(),
        Bindings::Explicit(bindings) => bindings.iter().map(|binding| resolve(binding, sources)).collect(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::kernel::binding::{ExecutableBinding, Source};
    use crate::kernel::reaction::CommandRef;

    fn bucket(pairs: &[(&str, Value)]) -> HashMap<String, Value> {
        pairs.iter().map(|(k, v)| (k.to_string(), v.clone())).collect()
    }

    fn command_ref() -> CommandRef {
        CommandRef { domain: None, command_name: "Account.Debit".to_string() }
    }

    #[test]
    fn verbatim_forwards_the_whole_payload_even_when_it_is_empty() {
        let dispatch = Dispatch { command_ref: command_ref(), bindings: Bindings::Verbatim };
        let mut sources = Sources::new();
        sources.insert("payload".to_string(), bucket(&[("amount", Value::Int(500))]));

        let resolved = resolve_dispatch_bindings(&dispatch, &sources);

        assert_eq!(resolved, bucket(&[("amount", Value::Int(500))]));
    }

    #[test]
    fn verbatim_with_no_payload_bucket_at_all_resolves_to_empty_not_a_panic() {
        let dispatch = Dispatch { command_ref: command_ref(), bindings: Bindings::Verbatim };
        let sources = Sources::new();

        assert_eq!(resolve_dispatch_bindings(&dispatch, &sources), HashMap::new());
    }

    #[test]
    fn an_empty_explicit_bindings_list_resolves_to_no_args_at_all_unlike_verbatim() {
        let dispatch = Dispatch { command_ref: command_ref(), bindings: Bindings::Explicit(vec![]) };
        let mut sources = Sources::new();
        sources.insert("payload".to_string(), bucket(&[("amount", Value::Int(500))]));

        // The real, distinct third case Dispatch::VERBATIM exists for —
        // Bindings::Explicit(vec![]) does NOT forward the payload, even
        // though a Verbatim dispatch given the SAME sources would.
        assert_eq!(resolve_dispatch_bindings(&dispatch, &sources), HashMap::new());
    }

    #[test]
    fn explicit_bindings_resolve_each_one_against_the_real_sources() {
        let binding = ExecutableBinding {
            destination: "account".to_string(),
            source: Source::Reference { name: "account_id".to_string(), priority: vec!["payload".to_string()] },
        };
        let dispatch = Dispatch { command_ref: command_ref(), bindings: Bindings::Explicit(vec![binding]) };
        let mut sources = Sources::new();
        sources.insert("payload".to_string(), bucket(&[("account_id", Value::Str("acc-1".to_string()))]));

        let resolved = resolve_dispatch_bindings(&dispatch, &sources);

        assert_eq!(resolved, bucket(&[("account", Value::Str("acc-1".to_string()))]));
    }

    #[test]
    fn a_literal_binding_carries_its_own_value_through_untouched_by_sources() {
        let binding = ExecutableBinding {
            destination: "kind".to_string(),
            source: Source::Literal { value: Value::Str("refund".to_string()) },
        };
        let dispatch = Dispatch { command_ref: command_ref(), bindings: Bindings::Explicit(vec![binding]) };
        let sources = Sources::new();

        let resolved = resolve_dispatch_bindings(&dispatch, &sources);

        assert_eq!(resolved, bucket(&[("kind", Value::Str("refund".to_string()))]));
    }
}
