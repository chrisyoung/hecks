// Implements the Ruby grammar's "block_predicate" expression-operator
// category (projection.json: `.all?`, `.any?`, `.none?`, `.find` — four
// symbols, two interpreter nodes) — `Resolver::BlockPredicate`/`Find`
// (resolver/block_predicates.rb), read directly. Admitted in the "gaps"
// follow-up pass via a fifth `Strategy` value, `block_predicate_match`
// (expression.bluebook's own `Operator.Propose` given, extended) — none
// of the original four strategies describes a `{ |x| ... }`-opening
// operator.
//
// BOTH REFUSE, ALWAYS — a real, named gap, not a router bug, the exact
// same reason `string::split`/`accessor::{first,last}` already refuse
// (their own headers). `Value::List` carries its own LENGTH ONLY
// (`expr/logic.rs`'s own header); a block predicate needs to bind its own
// `param` to EACH real element of the receiver in turn and evaluate
// `predicate` against it, which a bare length cannot support under any
// circumstance — the identical dependency `split`/`first`/`last` are
// already blocked on. Closing this for real needs `Value::List` to carry
// actual elements (`List(Vec<Value>)`, not `List(usize)`), the same
// architectural change those three are blocked on — out of scope here,
// not a missing line in this file.
//
// EVERY `Value` VARIANT IS NAMED BELOW, NONE LEFT TO A WILDCARD — see
// `sized.rs`'s own header for why: a `List` and a non-`List` refuse for
// two DIFFERENT, equally real reasons (one architectural, one a type
// mismatch a real domain predicate could actually hit), so both stay
// distinguishable in the message rather than collapsed into one
// catch-all. `expr/logic.rs`'s `category_of` guarantees each function
// below is only ever called with its own node kind — see `logical.rs`'s
// own header for why the trailing router-bug arms are not real refusal
// paths.

use crate::kernel::expr::{eval_error, interpret as eval, EvalContext, Expr, Value};
use crate::kernel::Refusal;

pub fn block_predicate(expr: &Expr, ctx: &EvalContext) -> Result<Value, Refusal> {
    let Expr::BlockPredicate { mode, receiver, .. } = expr else {
        return Err(Refusal::TypeMismatch(format!("block_predicate::block_predicate called with a non-block-predicate node {expr:?} — a router bug")));
    };

    match eval(receiver, ctx)? {
        Value::List(_) => Err(eval_error(format!("{mode}? cannot yet bind real elements in the Rust kernel — Value::List carries only a length, not elements; this is a known, named gap, not a router bug"))),
        v => Err(eval_error(format!("{mode}? expects a list, got {v:?}"))),
    }
}

pub fn find(expr: &Expr, ctx: &EvalContext) -> Result<Value, Refusal> {
    let Expr::Find { receiver, .. } = expr else {
        return Err(Refusal::TypeMismatch(format!("block_predicate::find called with a non-find node {expr:?} — a router bug")));
    };

    match eval(receiver, ctx)? {
        Value::List(_) => Err(eval_error("find cannot yet bind real elements in the Rust kernel — Value::List carries only a length, not elements; this is a known, named gap, not a router bug".to_string())),
        v => Err(eval_error(format!("find expects a list, got {v:?}"))),
    }
}
