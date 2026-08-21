// Implements the Ruby grammar's "block_predicate" expression-operator
// category (projection.json: `.all?`, `.any?`, `.none?`, `.find` — four
// symbols, two interpreter nodes) — `Resolver::BlockPredicate`/`Find`
// (resolver/block_predicates.rb), read directly. Admitted in the "gaps"
// follow-up pass via a fifth `Strategy` value, `block_predicate_match`
// (expression.bluebook's own `Operator.Propose` given, extended) — none
// of the original four strategies describes a `{ |x| ... }`-opening
// operator.
//
// BOTH REAL NOW, over `Value::Elements` — the same PRD 09 gap-closing
// pass that made `string::split`/`accessor::{first,last}` real.
// `interpret_with_element`'s own Ruby shape (`attrs.merge(node.param.to_sym
// => element)`) is ported via `BoundElement` (`expr/logic.rs`) — one
// name bound to the current element, checked first, falling through to
// the surrounding `args` for everything else, for the span of one
// predicate evaluation only.
//
// A STORED list attribute (`Value::List`) STILL cannot bind real
// elements — that gap is real and stays open, same as everywhere else
// in this pass — and `.find`'s own trailing dotted `.path` projection
// stays unimplemented too: `Value::Elements` only ever holds plain
// scalars (`.split`'s own output), which have no fields a path could
// walk, so a non-empty `path` refuses explicitly rather than silently
// answering nothing meaningful.
//
// NO REAL CORPUS FIXTURE EXERCISES ANY OF THIS TODAY — see `string.rs`'s
// own header for the full explanation and what "verified" means here
// instead (hand-written unit tests, not `rust_conformance_spec.rb`).
//
// EVERY `Value` VARIANT IS NAMED BELOW, NONE LEFT TO A WILDCARD — see
// `sized.rs`'s own header for why. `expr/logic.rs`'s `category_of`
// guarantees each function below is only ever called with its own node
// kind — see `logical.rs`'s own header for why the trailing router-bug
// arms are not real refusal paths.

use crate::kernel::expr::{eval_error, interpret as eval, BoundElement, EvalContext, Expr, Value};
use crate::kernel::Refusal;

pub fn block_predicate(expr: &Expr, ctx: &EvalContext) -> Result<Value, Refusal> {
    let Expr::BlockPredicate { mode, receiver, param, predicate } = expr else {
        return Err(Refusal::TypeMismatch(format!("block_predicate::block_predicate called with a non-block-predicate node {expr:?} — a router bug")));
    };

    let elements = match eval(receiver, ctx)? {
        Value::Elements(elements) => elements,
        Value::List(_) => return Err(eval_error(format!("{mode}? cannot yet bind real elements from a STORED list attribute in the Rust kernel — Value::List carries only a length, not elements; this is a known, named gap, not a router bug"))),
        v => return Err(eval_error(format!("{mode}? expects a list, got {v:?}"))),
    };

    let mut outcomes = Vec::with_capacity(elements.len());
    for element in elements {
        let bound = BoundElement { name: param.as_str(), value: element, inner: ctx.args };
        let bound_ctx = EvalContext { args: &bound, instance: ctx.instance };
        outcomes.push(eval(predicate, &bound_ctx)?.truthy());
    }

    // `BLOCK_PREDICATE_MODES` (resolver/block_predicates.rb) declares
    // exactly these three names, one per admitted symbol
    // (`.all?`/`.any?`/`.none?`) — a fourth string here is a codegen bug
    // (this `Expr` variant only ever gets built from one of those three
    // suffixes), not a real refusal, so it's reported the same
    // "the generator is wrong" way `dispatch_operator`'s own router-bug
    // arms already are.
    let result = match mode.as_str() {
        "all" => outcomes.iter().all(|outcome| *outcome),
        "any" => outcomes.iter().any(|outcome| *outcome),
        "none" => outcomes.iter().all(|outcome| !*outcome),
        other => return Err(Refusal::TypeMismatch(format!("block_predicate::block_predicate got mode {other:?}, not one of all/any/none — a router bug"))),
    };

    Ok(Value::Bool(result))
}

pub fn find(expr: &Expr, ctx: &EvalContext) -> Result<Value, Refusal> {
    let Expr::Find { receiver, param, predicate, path } = expr else {
        return Err(Refusal::TypeMismatch(format!("block_predicate::find called with a non-find node {expr:?} — a router bug")));
    };

    let elements = match eval(receiver, ctx)? {
        Value::Elements(elements) => elements,
        Value::List(_) => return Err(eval_error("find cannot yet bind real elements from a STORED list attribute in the Rust kernel — Value::List carries only a length, not elements; this is a known, named gap, not a router bug".to_string())),
        v => return Err(eval_error(format!("find expects a list, got {v:?}"))),
    };

    let mut found = None;
    for element in elements {
        let bound = BoundElement { name: param.as_str(), value: element.clone(), inner: ctx.args };
        let bound_ctx = EvalContext { args: &bound, instance: ctx.instance };
        if eval(predicate, &bound_ctx)?.truthy() {
            found = Some(element);
            break;
        }
    }

    match found {
        None => Ok(Value::Nil),
        Some(value) if path.is_empty() => Ok(value),
        Some(_) => Err(eval_error("find's own trailing dotted path cannot yet project through a real element in the Rust kernel — Value::Elements only ever holds plain scalars (from .split), which have no fields to walk; this is a known, named gap, not a router bug".to_string())),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::kernel::expr::{Comparison, Field, Fielded};

    /// Answers ONE fixed lookup name (`"list"`) with a real
    /// `Value::Elements` — there is no `Expr::Elements` literal node
    /// (canonical text never spells one directly; only `.split` ever
    /// produces one at runtime), so tests reach a real `Elements` value
    /// through `Expr::Lookup("list")` against this fake `Fielded`,
    /// rather than round-tripping through a real `.split` call (which
    /// would risk its own trailing-empty-string rule silently eating an
    /// intentionally-empty test element — a real bug this file's first
    /// draft had, caught before it shipped).
    struct FixedList(Vec<Value>);

    impl Fielded for FixedList {
        fn field(&self, name: &str) -> Option<Field<'_>> {
            (name == "list").then(|| Field::Value(Value::Elements(self.0.clone())))
        }
    }

    fn elements(values: &[&str]) -> Vec<Value> {
        values.iter().map(|s| Value::Str(s.to_string())).collect()
    }

    fn ctx_over(values: &[&str]) -> (FixedList, Expr) {
        (FixedList(elements(values)), Expr::Lookup("list"))
    }

    // `s.length > 0` — the real corpus-shaped predicate the "gaps" pass's
    // own doc comments quote from resolver.rb's own history
    // (`.split("::").all? { |s| s.length > 0 }`), built from real `Expr`
    // nodes rather than a stand-in.
    // `>`'s real encoding (comparison.rs's own doc table, evaluator.rb's
    // OPERATORS): less_than: true, equal: true, negated: true —
    // `a > b == !(a < b || a == b)`. Got this wrong on the first pass
    // (wrote `>=`'s encoding by mistake, `equal: false`) — caught by the
    // tests below actually failing, not assumed correct because it
    // compiled.
    fn length_greater_than_zero() -> Expr {
        Expr::Compare {
            op: Comparison { less_than: true, equal: true, negated: true },
            left: Box::new(Expr::Size(Box::new(Expr::Lookup("s")))),
            right: Box::new(Expr::Int(0)),
        }
    }

    #[test]
    fn all_is_true_when_every_element_satisfies_the_predicate() {
        let (list, receiver) = ctx_over(&["ab", "cd"]);
        let ctx = EvalContext { args: &list, instance: &list };
        let node = Expr::BlockPredicate {
            mode: "all".to_string(), receiver: Box::new(receiver),
            param: "s".to_string(), predicate: Box::new(length_greater_than_zero()),
        };

        assert_eq!(block_predicate(&node, &ctx).unwrap(), Value::Bool(true));
    }

    #[test]
    fn all_is_false_when_one_element_fails_the_predicate() {
        let (list, receiver) = ctx_over(&["ab", ""]);
        let ctx = EvalContext { args: &list, instance: &list };
        let node = Expr::BlockPredicate {
            mode: "all".to_string(), receiver: Box::new(receiver),
            param: "s".to_string(), predicate: Box::new(length_greater_than_zero()),
        };

        assert_eq!(block_predicate(&node, &ctx).unwrap(), Value::Bool(false));
    }

    #[test]
    fn any_is_true_when_at_least_one_element_satisfies_the_predicate() {
        let (list, receiver) = ctx_over(&["", "cd"]);
        let ctx = EvalContext { args: &list, instance: &list };
        let node = Expr::BlockPredicate {
            mode: "any".to_string(), receiver: Box::new(receiver),
            param: "s".to_string(), predicate: Box::new(length_greater_than_zero()),
        };

        assert_eq!(block_predicate(&node, &ctx).unwrap(), Value::Bool(true));
    }

    #[test]
    fn none_is_true_when_no_element_satisfies_the_predicate() {
        let (list, receiver) = ctx_over(&["", ""]);
        let ctx = EvalContext { args: &list, instance: &list };
        let node = Expr::BlockPredicate {
            mode: "none".to_string(), receiver: Box::new(receiver),
            param: "s".to_string(), predicate: Box::new(length_greater_than_zero()),
        };

        assert_eq!(block_predicate(&node, &ctx).unwrap(), Value::Bool(true));
    }

    #[test]
    fn all_any_none_answer_the_ruby_shaped_vacuous_case_on_an_empty_sequence() {
        // Ruby: [].all? == true, [].any? == false, [].none? == true —
        // the SAME vacuous-truth convention `Vec::all()`/`any()` over
        // zero elements reproduces here.
        for (mode, expected) in [("all", true), ("any", false), ("none", true)] {
            let (list, receiver) = ctx_over(&[]);
            let ctx = EvalContext { args: &list, instance: &list };
            let node = Expr::BlockPredicate {
                mode: mode.to_string(), receiver: Box::new(receiver),
                param: "s".to_string(), predicate: Box::new(length_greater_than_zero()),
            };
            assert_eq!(block_predicate(&node, &ctx).unwrap(), Value::Bool(expected), "mode {mode}");
        }
    }

    #[test]
    fn find_answers_the_first_element_the_predicate_accepts() {
        let (list, receiver) = ctx_over(&["", "cd", "ef"]);
        let ctx = EvalContext { args: &list, instance: &list };
        let node = Expr::Find {
            receiver: Box::new(receiver), param: "s".to_string(),
            predicate: Box::new(length_greater_than_zero()), path: vec![],
        };

        assert_eq!(find(&node, &ctx).unwrap(), Value::Str("cd".to_string()));
    }

    #[test]
    fn find_answers_nil_when_nothing_matches_matching_rubys_own_semantics() {
        let (list, receiver) = ctx_over(&["", ""]);
        let ctx = EvalContext { args: &list, instance: &list };
        let node = Expr::Find {
            receiver: Box::new(receiver), param: "s".to_string(),
            predicate: Box::new(length_greater_than_zero()), path: vec![],
        };

        assert_eq!(find(&node, &ctx).unwrap(), Value::Nil);
    }

    #[test]
    fn find_with_a_trailing_path_refuses_explicitly_rather_than_silently_answering_wrong() {
        let (list, receiver) = ctx_over(&["cd"]);
        let ctx = EvalContext { args: &list, instance: &list };
        let node = Expr::Find {
            receiver: Box::new(receiver), param: "s".to_string(),
            predicate: Box::new(length_greater_than_zero()), path: vec!["some_field".to_string()],
        };

        assert!(find(&node, &ctx).is_err());
    }
}
