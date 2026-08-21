// Implements the Ruby grammar's "block_predicate" expression-operator
// category (projection.json: `.all?`, `.any?`, `.none?`, `.find` — four
// symbols, two interpreter nodes) — `Resolver::BlockPredicate`/`Find`
// (resolver/block_predicates.rb), read directly. Admitted in the "gaps"
// follow-up pass via a fifth `Strategy` value, `block_predicate_match`
// (expression.bluebook's own `Operator.Propose` given, extended) — none
// of the original four strategies describes a `{ |x| ... }`-opening
// operator.
//
// BOTH REAL NOW, over BOTH real element sources — PRD 09's own
// gap-closing pass (`.split`-produced `Value::Elements`), and the "fix
// the gaps, continued" pass on top of it (a STORED list attribute's own
// real elements, `Field::NestedList` — `expr/logic.rs`'s own header).
// `interpret_with_element`'s own Ruby shape (`attrs.merge(node.param.to_sym
// => element)`) is ported via `BoundElement` (`expr/logic.rs`) — one
// name bound to the current element, checked first, falling through to
// the surrounding `args` for everything else, for the span of one
// predicate evaluation only. `BoundElement` binds a `Field`, not a bare
// `Value` — a `.split`-produced element is always a plain scalar
// (`Field::Value`), but a STORED element is a real, possibly
// multi-field struct (`Field::Nested`), and a predicate like `.all? {
// |n| n.strategy == strategy }` needs `n.strategy` to resolve through
// the bound element's own `Fielded::field`, not a pre-collapsed scalar.
//
// `.find`'s own trailing dotted `.path` projection is real now too, for
// the STORED-list source — `composite::step`/`finish` walk it through
// the found element's own `Fielded` impl, the exact "find-then-project"
// shape this struct's own header quotes as the motivating case (`legs.
// find { |l| ... }.next_load_location`). It STAYS a refusal for a
// `.split`-produced match: `Value::Elements` only ever holds plain
// scalars, which have no fields any path could walk, so a non-empty
// `path` there is a real refusal, not a router bug.
//
// NO REAL CORPUS FIXTURE EXERCISES THE `.split`-PRODUCED PATH — see
// `string.rs`'s own header for the full explanation. The STORED-list
// path DOES have one now — `reaction.bluebook`'s own `Normalise`/
// `Attach` `ensures` checks — see `accessor.rs`'s own header for the
// same note.
//
// EVERY `Field`/`Value` VARIANT IS NAMED BELOW, NONE LEFT TO A
// WILDCARD — see `sized.rs`'s own header for why. `expr/logic.rs`'s
// `category_of` guarantees each function below is only ever called with
// its own node kind — see `logical.rs`'s own header for why the
// trailing router-bug arms are not real refusal paths.

use crate::kernel::attribute_shapes::composite;
use crate::kernel::expr::{eval_error, interpret as eval, interpret_as_field, BoundElement, EvalContext, Expr, Field, Value};
use crate::kernel::Refusal;

pub fn block_predicate(expr: &Expr, ctx: &EvalContext) -> Result<Value, Refusal> {
    let Expr::BlockPredicate { mode, receiver, param, predicate } = expr else {
        return Err(Refusal::TypeMismatch(format!("block_predicate::block_predicate called with a non-block-predicate node {expr:?} — a router bug")));
    };

    let outcomes: Vec<bool> = match interpret_as_field(receiver, ctx)? {
        Field::Value(Value::Elements(elements)) => elements
            .into_iter()
            .map(|element| evaluate_one(param, predicate, Field::Value(element), ctx))
            .collect::<Result<_, _>>()?,
        Field::NestedList(list) => (0..list.list_len())
            .map(|i| evaluate_one(param, predicate, Field::Nested(list.list_get(i)), ctx))
            .collect::<Result<_, _>>()?,
        Field::Value(v) => return Err(eval_error(format!("{mode}? expects a list, got {v:?}"))),
        Field::Nested(_) => return Err(eval_error(format!("{mode}? expects a list, got a single nested object"))),
    };

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

    match interpret_as_field(receiver, ctx)? {
        Field::Value(Value::Elements(elements)) => {
            let mut found = None;
            for element in elements {
                if evaluate_one(param, predicate, Field::Value(element.clone()), ctx)? {
                    found = Some(element);
                    break;
                }
            }
            match found {
                None => Ok(Value::Nil),
                Some(value) if path.is_empty() => Ok(value),
                Some(_) => Err(eval_error("find's own trailing dotted path cannot project through a .split-produced element — Value::Elements only ever holds plain scalars, which have no fields to walk; this is a real refusal, not a router bug".to_string())),
            }
        }
        Field::NestedList(list) => {
            for i in 0..list.list_len() {
                let element = list.list_get(i);
                if evaluate_one(param, predicate, Field::Nested(element), ctx)? {
                    let mut current = Field::Nested(element);
                    for seg in path {
                        current = composite::step(current, seg, "find", "find")?;
                    }
                    return composite::finish(current, "find");
                }
            }
            Ok(Value::Nil)
        }
        Field::Value(v) => Err(eval_error(format!("find expects a list, got {v:?}"))),
        Field::Nested(_) => Err(eval_error("find expects a list, got a single nested object".to_string())),
    }
}

/// Shared by `block_predicate`/`find` — binds `param` to `bound` (the
/// current element, either shape) for the span of evaluating `predicate`
/// against it once, exactly `Resolver#interpret_with_element`'s own
/// contract (this file's own header).
fn evaluate_one(param: &str, predicate: &Expr, bound: Field<'_>, ctx: &EvalContext) -> Result<bool, Refusal> {
    let bound_element = BoundElement { name: param, value: bound, inner: ctx.args };
    let bound_ctx = EvalContext { args: &bound_element, instance: ctx.instance };
    Ok(eval(predicate, &bound_ctx)?.truthy())
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

    // "Fix the gaps, continued" — the STORED-list source, a real
    // multi-field element (`n.strategy`/`n.source_token`, mirroring
    // `reaction.bluebook`'s own `Normalise` rule fields — the exact
    // motivating shape the "use the new predicates in bluebook.bluebook"
    // pass reaches for real). Distinct fixture from `FixedList` above:
    // this one answers `Field::NestedList`, not `Field::Value(Elements)`,
    // and each element is itself dotted-path walkable — the case
    // `BoundElement`'s own `Field`-not-`Value` binding exists for.
    struct Rule {
        strategy: &'static str,
        source_token: &'static str,
    }

    impl Fielded for Rule {
        fn field(&self, name: &str) -> Option<Field<'_>> {
            match name {
                "strategy" => Some(Field::Value(Value::Str(self.strategy.to_string()))),
                "source_token" => Some(Field::Value(Value::Str(self.source_token.to_string()))),
                _ => None,
            }
        }
    }

    struct FixedStoredList(Vec<Rule>);
    impl Fielded for FixedStoredList {
        fn field(&self, name: &str) -> Option<Field<'_>> {
            (name == "rules").then(|| Field::NestedList(&self.0))
        }
    }

    fn equals(field: &'static str, text: &'static str) -> Expr {
        Expr::Compare {
            op: Comparison { less_than: false, equal: true, negated: false },
            left: Box::new(Expr::Lookup(field)),
            right: Box::new(Expr::Str(text.to_string())),
        }
    }

    // `n.strategy == "collapse" && n.source_token == "  "` — a real
    // multi-field predicate, projecting into the bound element's OWN
    // fields rather than comparing it as one opaque scalar. The `"n."`
    // prefix is real, not decorative: `equals`'s own `Expr::Lookup` is
    // a DOTTED path, walked head-first through `n` (the bound param)
    // THEN into `.strategy` via `composite::step` — a bare
    // `Expr::Lookup("strategy")` would look `strategy` up as its own
    // top-level argument/instance field instead, which this file's own
    // first draft got wrong and these tests caught failing outright
    // (`cannot resolve "strategy"`), not silently.
    fn matches_the_collapse_rule() -> Expr {
        Expr::And(Box::new(equals("n.strategy", "collapse")), Box::new(equals("n.source_token", "  ")))
    }

    #[test]
    fn none_is_true_over_a_stored_list_when_no_element_matches_by_its_own_fields() {
        let list = FixedStoredList(vec![
            Rule { strategy: "rewrite", source_token: "x" },
            Rule { strategy: "collapse", source_token: "y" },
        ]);
        let ctx = EvalContext { args: &list, instance: &list };
        let node = Expr::BlockPredicate {
            mode: "none".to_string(), receiver: Box::new(Expr::Lookup("rules")),
            param: "n".to_string(), predicate: Box::new(matches_the_collapse_rule()),
        };

        assert_eq!(block_predicate(&node, &ctx).unwrap(), Value::Bool(true));
    }

    #[test]
    fn any_is_true_over_a_stored_list_when_one_element_matches_by_its_own_fields() {
        let list = FixedStoredList(vec![
            Rule { strategy: "rewrite", source_token: "x" },
            Rule { strategy: "collapse", source_token: "  " },
        ]);
        let ctx = EvalContext { args: &list, instance: &list };
        let node = Expr::BlockPredicate {
            mode: "any".to_string(), receiver: Box::new(Expr::Lookup("rules")),
            param: "n".to_string(), predicate: Box::new(matches_the_collapse_rule()),
        };

        assert_eq!(block_predicate(&node, &ctx).unwrap(), Value::Bool(true));
    }

    #[test]
    fn find_over_a_stored_list_projects_its_own_trailing_path_through_the_found_element() {
        let list = FixedStoredList(vec![
            Rule { strategy: "rewrite", source_token: "x" },
            Rule { strategy: "collapse", source_token: "target" },
        ]);
        let ctx = EvalContext { args: &list, instance: &list };
        let node = Expr::Find {
            receiver: Box::new(Expr::Lookup("rules")), param: "n".to_string(),
            predicate: Box::new(equals("n.strategy", "collapse")), path: vec!["source_token".to_string()],
        };

        assert_eq!(find(&node, &ctx).unwrap(), Value::Str("target".to_string()));
    }

    #[test]
    fn find_over_a_stored_list_answers_nil_when_nothing_matches() {
        let list = FixedStoredList(vec![Rule { strategy: "rewrite", source_token: "x" }]);
        let ctx = EvalContext { args: &list, instance: &list };
        let node = Expr::Find {
            receiver: Box::new(Expr::Lookup("rules")), param: "n".to_string(),
            predicate: Box::new(equals("n.strategy", "collapse")), path: vec!["source_token".to_string()],
        };

        assert_eq!(find(&node, &ctx).unwrap(), Value::Nil);
    }
}
