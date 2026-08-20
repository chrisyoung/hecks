// Implements the Ruby grammar's "accessor" expression-operator category
// (projection.json: `.first`, `.last` — two symbols, two interpreter
// nodes) — `Resolver::First`/`Last` (resolver.rb), read directly. PRD
// 09 — admitted alongside `.match?`/`.present?`/`.blank?`/`.split`/
// `.start_with?`/`.end_with?`, all previously real in Ruby's `Resolver`
// and ungoverned by the operator ledger entirely.
//
// BOTH REFUSE, ALWAYS — a real, named gap, not a router bug. `Value::List`
// carries its own LENGTH ONLY (`expr.rs`'s own header,
// `attribute_shapes/list.rs`'s own header); `.first`/`.last` exist
// exactly to hand back one ELEMENT, which a bare length cannot
// represent under any circumstance — unlike `string::split` (also
// refused, same reasoning, that file's own header), there is no
// intermediate case here where the answer happens to be knowable from
// the count alone. Every real corpus usage of `.first`/`.last` receives
// a `Split`-produced Array in Ruby (resolver.rb's own comment on
// `Last`) — the identical dependency `string::split`'s own refusal
// already names. Closing this for real needs `Value::List` to carry
// actual elements (`List(Vec<Value>)`, not `List(usize)`), the same
// architectural change `string.rs` is blocked on — out of PRD 09's own
// scope, not a missing line in this file.
//
// EVERY `Value` VARIANT IS NAMED BELOW, NONE LEFT TO A WILDCARD — see
// `sized.rs`'s own header for why: a `List` and a non-`List` refuse for
// two DIFFERENT, equally real reasons (one architectural, one a type
// mismatch a real domain predicate could actually hit), so both stay
// distinguishable in the message rather than collapsed into one
// catch-all. `expr.rs`'s `category_of` guarantees each function below is
// only ever called with its own node kind — see `logical.rs`'s own
// header for why the trailing router-bug arms are not real refusal
// paths.

use crate::kernel::expr::{eval_error, interpret as eval, EvalContext, Expr, Value};
use crate::kernel::Refusal;

pub fn first(expr: &Expr, ctx: &EvalContext) -> Result<Value, Refusal> {
    let Expr::First(receiver) = expr else {
        return Err(Refusal::TypeMismatch(format!("accessor::first called with a non-first node {expr:?} — a router bug")));
    };

    match eval(receiver, ctx)? {
        Value::List(_) => Err(eval_error("first cannot yet produce a real element in the Rust kernel — Value::List carries only a length, not elements; this is a known, named gap (PRD 09), not a router bug".to_string())),
        v => Err(eval_error(format!("first expects a list, got {v:?}"))),
    }
}

pub fn last(expr: &Expr, ctx: &EvalContext) -> Result<Value, Refusal> {
    let Expr::Last(receiver) = expr else {
        return Err(Refusal::TypeMismatch(format!("accessor::last called with a non-last node {expr:?} — a router bug")));
    };

    match eval(receiver, ctx)? {
        Value::List(_) => Err(eval_error("last cannot yet produce a real element in the Rust kernel — Value::List carries only a length, not elements; this is a known, named gap (PRD 09), not a router bug".to_string())),
        v => Err(eval_error(format!("last expects a list, got {v:?}"))),
    }
}
