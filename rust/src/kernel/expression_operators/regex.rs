// Implements the Ruby grammar's "regex" expression-operator category
// (projection.json: `.match?`, its one member) — `Resolver::MatchesRegex`/
// `Resolver.matches_regex?` (resolver.rb), read directly. PRD 09 —
// admitted alongside `.present?`/`.blank?`/`.split`/`.first`/`.last`/
// `.start_with?`/`.end_with?`, all previously real in Ruby's `Resolver`
// and ungoverned by the operator ledger entirely. `.match?` is the SINGLE
// most corpus-exercised of the eight (resolver.rb's own comment: "nearly
// every value_object's format-validation rule across every corpus"),
// unlike `.split`/`.first`/`.last`, which stay refused — worth the one
// real dependency this file needs (rust/Cargo.toml's own new
// `[dependencies]` section, flagged there for the same reason).
//
// Coercion mirrors `Resolver.matches_regex?` FIELD FOR FIELD, not
// "helpfully" extended: `Str`/`Int`/`Float`/`Nil` stringify (`Nil` to
// `""`), and `Bool` REFUSES — Ruby's own `case` has no `TrueClass`/
// `FalseClass` arm and falls to `else raise`, so this kernel refuses the
// identical input Ruby itself refuses, not a wider set.
//
// EVERY `Value` VARIANT IS NAMED BELOW, NONE LEFT TO A WILDCARD — see
// `sized.rs`'s own header for why. `expr.rs`'s `category_of` guarantees
// `interpret` below is only ever called with `MatchesRegex` — see
// `logical.rs`'s own header for why the trailing arm is a router-bug
// guard, not a real refusal path.

use crate::kernel::expr::{eval_error, interpret as eval, EvalContext, Expr, Value};
use crate::kernel::Refusal;
use regex::RegexBuilder;

pub fn interpret(expr: &Expr, ctx: &EvalContext) -> Result<Value, Refusal> {
    let Expr::MatchesRegex { receiver, pattern, flags } = expr else {
        return Err(Refusal::TypeMismatch(format!("regex::interpret called with a non-match? node {expr:?} — a router bug")));
    };

    let text = coerce(&eval(receiver, ctx)?)?;

    // `x` (EXTENDED) has no `RegexBuilder` flag in the `regex` crate the
    // way `i`/`m` do — Ruby's own `Regexp::EXTENDED` and Rust's inline
    // `(?x)` mode are the SAME feature (ignore unescaped whitespace and
    // `#`-comments in the pattern), just spelled differently per crate,
    // so it's prepended to the pattern text instead of set on the
    // builder.
    let pattern = if flags.contains('x') { format!("(?x){pattern}") } else { pattern.clone() };

    let re = RegexBuilder::new(&pattern)
        .case_insensitive(flags.contains('i'))
        .multi_line(flags.contains('m'))
        .build()
        .map_err(|e| eval_error(format!("match? given an invalid pattern {pattern:?}: {e}")))?;

    Ok(Value::Bool(re.is_match(&text)))
}

fn coerce(v: &Value) -> Result<String, Refusal> {
    match v {
        Value::Str(s) => Ok(s.clone()),
        Value::Int(i) => Ok(i.to_string()),
        Value::Float(f) => Ok(f.to_string()),
        Value::Nil => Ok(String::new()),
        Value::Bool(_) | Value::List(_) | Value::Elements(_) => Err(eval_error(format!("match? expects a scalar, got {v:?}"))),
    }
}

#[cfg(test)]
mod tests {
    use super::coerce;
    use crate::kernel::expr::Value;

    // Field-for-field against `Resolver.matches_regex?`'s own `case`
    // (resolver.rb) — Bool is the one deliberate omission: Ruby's `case`
    // has no `TrueClass`/`FalseClass` arm and falls to `else raise`, so
    // this kernel refuses the SAME input Ruby itself refuses, not a
    // wider set (this file's own header).
    #[test]
    fn coerces_every_shape_ruby_coerces_and_refuses_the_one_it_refuses() {
        assert_eq!(coerce(&Value::Str("x".to_string())).unwrap(), "x");
        assert_eq!(coerce(&Value::Int(5)).unwrap(), "5");
        assert_eq!(coerce(&Value::Float(1.5)).unwrap(), "1.5");
        assert_eq!(coerce(&Value::Nil).unwrap(), "");

        assert!(coerce(&Value::Bool(true)).is_err());
        assert!(coerce(&Value::List(0)).is_err());
    }
}
