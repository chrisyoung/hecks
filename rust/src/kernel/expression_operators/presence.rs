// Implements the Ruby grammar's "presence" expression-operator category
// (projection.json: `.present?`, `.blank?` — two symbols, one
// interpreter node distinguished by `negated`, the same shape
// `sign_test.rs` already uses for its own three-symbols-one-node family)
// — `Resolver::Presence`/`Resolver.blank?` (resolver.rb), read directly.
// PRD 09 — admitted alongside `.match?`/`.split`/`.first`/`.last`/
// `.start_with?`/`.end_with?`, all previously real in Ruby's `Resolver`
// and ungoverned by the operator ledger entirely.
//
// `nil`/`false` are blank ; a `Str`/`List` is blank when EMPTY, not
// merely falsy — ported field-for-field from `Resolver.blank?`, not
// reinvented: `Int`/`Float`/`Bool(true)` are never blank (Ruby's own
// `else false` branch — a number or `true` is always present).
//
// EVERY `Value` VARIANT IS NAMED BELOW, NONE LEFT TO A WILDCARD — see
// `sized.rs`'s own header for why. `expr.rs`'s `category_of` guarantees
// `interpret` below is only ever called with `Presence` — see
// `logical.rs`'s own header for why the trailing arm is a router-bug
// guard, not a real refusal path.

use crate::kernel::expr::{interpret as eval, EvalContext, Expr, Value};
use crate::kernel::Refusal;

pub fn interpret(expr: &Expr, ctx: &EvalContext) -> Result<Value, Refusal> {
    let Expr::Presence { receiver, negated } = expr else {
        return Err(Refusal::TypeMismatch(format!("presence::interpret called with a non-presence node {expr:?} — a router bug")));
    };

    let present = !blank(&eval(receiver, ctx)?);
    Ok(Value::Bool(if *negated { !present } else { present }))
}

fn blank(v: &Value) -> bool {
    match v {
        Value::Nil => true,
        Value::Bool(b) => !*b,
        Value::Str(s) => s.is_empty(),
        Value::List(n) => *n == 0,
        // PRD 09 gap-closing pass — Elements is blank when empty, the
        // identical rule List already has (both are Ruby's own Array
        // blank-when-empty semantics; Elements just carries real
        // members instead of a bare count).
        Value::Elements(elements) => elements.is_empty(),
        Value::Int(_) | Value::Float(_) => false,
    }
}

#[cfg(test)]
mod tests {
    use super::blank;
    use crate::kernel::expr::Value;

    // Every case here is a real `Resolver.blank?` call, checked against
    // resolver.rb's own logic before this test was written — a number or
    // `true` is NEVER blank (Ruby's own `else false` branch), unlike
    // `nil`/`false`/an empty `Str`/`List`, which always are.
    #[test]
    fn matches_ruby_blank_across_every_value_shape() {
        assert!(blank(&Value::Nil));
        assert!(blank(&Value::Bool(false)));
        assert!(blank(&Value::Str(String::new())));
        assert!(blank(&Value::List(0)));

        assert!(!blank(&Value::Bool(true)));
        assert!(!blank(&Value::Str("x".to_string())));
        assert!(!blank(&Value::List(1)));
        assert!(!blank(&Value::Int(0)));
        assert!(!blank(&Value::Float(0.0)));
    }
}
