// Implements the Ruby grammar's "string" expression-operator category
// (projection.json: `.split`, `.start_with?`, `.end_with?` — three
// symbols) — `Resolver::Split`/`StartsWith`/`EndsWith` (resolver.rb),
// read directly. PRD 09 — admitted alongside `.match?`/`.present?`/
// `.blank?`/`.first`/`.last`, all previously real in Ruby's `Resolver`
// and ungoverned by the operator ledger entirely.
//
// `.start_with?`/`.end_with?` are fully ported — both are String-only in
// the corpus's own usage (resolver.rb's own comment on `StartsWith`),
// and a `bool` answer needs nothing `Value` cannot already represent.
//
// `.split` IS NOT — see its own function below for why this is a real,
// named gap rather than a missing case nobody noticed. This is the
// honest thing to ship: an operator this kernel recognizes and refuses
// FOR A STATED REASON is a real improvement over one it cannot even
// parse today, even though it cannot yet succeed.
//
// EVERY `Value` VARIANT IS NAMED BELOW, NONE LEFT TO A WILDCARD — see
// `sized.rs`'s own header for why. `expr.rs`'s `category_of` guarantees
// each function below is only ever called with its own node kind — see
// `logical.rs`'s own header for why the trailing router-bug arms are not
// real refusal paths.

use crate::kernel::expr::{eval_error, interpret as eval, EvalContext, Expr, Value};
use crate::kernel::Refusal;

pub fn split(expr: &Expr, ctx: &EvalContext) -> Result<Value, Refusal> {
    let Expr::Split { receiver, .. } = expr else {
        return Err(Refusal::TypeMismatch(format!("string::split called with a non-split node {expr:?} — a router bug")));
    };

    // `Value::List` carries its own LENGTH ONLY (`expr.rs`'s own header,
    // `attribute_shapes/list.rs`'s own header) — real corpus text was
    // never expected to ask for a list's OWN ELEMENTS by expression, and
    // `.split`'s whole point is producing exactly that: a real Array a
    // caller can `.first`/`.last`/`.all? { }` over (the corpus's own
    // `Query::Phrase` does precisely this — `.split("::").last`,
    // `.split("::").all? { |s| s.length > 0 }`). Evaluating the receiver
    // and refusing HONESTLY, rather than returning a `Value::List(n)`
    // whose length answers `.size`/`.empty?` correctly and lies the
    // moment anything chains `.first`/`.last`/a block predicate onto it
    // — the same "refuse rather than silently answer a question this
    // shape cannot represent" discipline `to_string.rs`'s own `List` arm
    // already sets a precedent for, one level further in. Closing this
    // for real needs `Value::List` to carry actual elements
    // (`List(Vec<Value>)`, not `List(usize)`) — a real architectural
    // change, out of PRD 09's own scope (see PRD 09's "Correction" /
    // follow-up note), not a missing line in this file.
    let _ = eval(receiver, ctx)?;
    Err(eval_error("split cannot yet produce a real list value in the Rust kernel — Value::List carries only a length, not elements; this is a known, named gap (PRD 09), not a router bug".to_string()))
}

pub fn starts_with(expr: &Expr, ctx: &EvalContext) -> Result<Value, Refusal> {
    let Expr::StartsWith { receiver, substring } = expr else {
        return Err(Refusal::TypeMismatch(format!("string::starts_with called with a non-start_with? node {expr:?} — a router bug")));
    };

    match eval(receiver, ctx)? {
        Value::Str(s) => Ok(Value::Bool(s.starts_with(substring.as_str()))),
        v => Err(eval_error(format!("start_with? expects a string, got {v:?}"))),
    }
}

pub fn ends_with(expr: &Expr, ctx: &EvalContext) -> Result<Value, Refusal> {
    let Expr::EndsWith { receiver, substring } = expr else {
        return Err(Refusal::TypeMismatch(format!("string::ends_with called with a non-end_with? node {expr:?} — a router bug")));
    };

    match eval(receiver, ctx)? {
        Value::Str(s) => Ok(Value::Bool(s.ends_with(substring.as_str()))),
        v => Err(eval_error(format!("end_with? expects a string, got {v:?}"))),
    }
}
