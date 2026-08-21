// Implements the Ruby grammar's "accessor" expression-operator category
// (projection.json: `.first`, `.last` — two symbols, two interpreter
// nodes) — `Resolver::First`/`Last` (resolver.rb), read directly. PRD
// 09 — admitted alongside `.match?`/`.present?`/`.blank?`/`.split`/
// `.start_with?`/`.end_with?`, all previously real in Ruby's `Resolver`
// and ungoverned by the operator ledger entirely.
//
// BOTH REAL NOW — PRD 09 gap-closing pass. `Value::List` (a stored
// attribute's own bare length — `expr/logic.rs`'s own header) still
// cannot answer either, and still refuses, explicitly — that gap is
// real and stays open (see `expr/logic.rs`'s own `Elements` doc for the
// full boundary). What changed is `Value::Elements`, a real element
// sequence `string::split` produces: `.first`/`.last` on THAT answer
// with the real first/last `Value`, `Ruby`'s own `[].first`/`[].last ==
// nil` on an empty one, matching Ruby exactly rather than refusing a
// case Ruby itself answers.
//
// NO REAL CORPUS FIXTURE EXERCISES THIS TODAY — see `string.rs`'s own
// header for the full explanation (this repo's actual corpus has zero
// real `.split`/`.first`/`.last`/`.all?`/`.find` usage); verified by
// hand-written unit tests instead of `rust_conformance_spec.rb`.
//
// EVERY `Value` VARIANT IS NAMED BELOW, NONE LEFT TO A WILDCARD — see
// `sized.rs`'s own header for why: `List`, `Elements`, and every other
// non-`Elements` shape each refuse (or succeed) for their own distinct,
// real reason, so none collapse into one catch-all. `expr.rs`'s
// `category_of` guarantees each function below is only ever called with
// its own node kind — see `logical.rs`'s own header for why the
// trailing router-bug arms are not real refusal paths.

use crate::kernel::expr::{eval_error, interpret as eval, EvalContext, Expr, Value};
use crate::kernel::Refusal;

pub fn first(expr: &Expr, ctx: &EvalContext) -> Result<Value, Refusal> {
    let Expr::First(receiver) = expr else {
        return Err(Refusal::TypeMismatch(format!("accessor::first called with a non-first node {expr:?} — a router bug")));
    };

    match eval(receiver, ctx)? {
        Value::Elements(elements) => Ok(elements.into_iter().next().unwrap_or(Value::Nil)),
        Value::List(_) => Err(eval_error("first cannot yet produce a real element from a STORED list attribute in the Rust kernel — Value::List carries only a length, not elements; this is a known, named gap, not a router bug".to_string())),
        v => Err(eval_error(format!("first expects a list, got {v:?}"))),
    }
}

pub fn last(expr: &Expr, ctx: &EvalContext) -> Result<Value, Refusal> {
    let Expr::Last(receiver) = expr else {
        return Err(Refusal::TypeMismatch(format!("accessor::last called with a non-last node {expr:?} — a router bug")));
    };

    match eval(receiver, ctx)? {
        Value::Elements(mut elements) => Ok(elements.pop().unwrap_or(Value::Nil)),
        Value::List(_) => Err(eval_error("last cannot yet produce a real element from a STORED list attribute in the Rust kernel — Value::List carries only a length, not elements; this is a known, named gap, not a router bug".to_string())),
        v => Err(eval_error(format!("last expects a list, got {v:?}"))),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn elements(values: Vec<&str>) -> Value {
        Value::Elements(values.into_iter().map(|s| Value::Str(s.to_string())).collect())
    }

    #[test]
    fn first_answers_the_real_first_element() {
        let Value::Elements(v) = elements(vec!["a", "b", "c"]) else { unreachable!() };
        assert_eq!(v.into_iter().next().unwrap_or(Value::Nil), Value::Str("a".to_string()));
    }

    #[test]
    fn last_answers_the_real_last_element() {
        let Value::Elements(mut v) = elements(vec!["a", "b", "c"]) else { unreachable!() };
        assert_eq!(v.pop().unwrap_or(Value::Nil), Value::Str("c".to_string()));
    }

    #[test]
    fn first_and_last_answer_nil_on_an_empty_sequence_matching_rubys_own_array_semantics() {
        let Value::Elements(v) = Value::Elements(vec![]) else { unreachable!() };
        assert_eq!(v.into_iter().next().unwrap_or(Value::Nil), Value::Nil);

        let Value::Elements(mut v2) = Value::Elements(vec![]) else { unreachable!() };
        assert_eq!(v2.pop().unwrap_or(Value::Nil), Value::Nil);
    }
}
