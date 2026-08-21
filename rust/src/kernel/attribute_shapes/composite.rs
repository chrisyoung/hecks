// Implements the `:composite` branch of `Runtime::Value::Coercion::SHAPES`
// (lib/hecksagain/runtime/value/coercion.rb) — `for_attribute`'s
// `coerced =` line: the attribute's type names a DECLARED value object,
// rebuilt recursively via `Value.build`. By the time an expression is
// being EVALUATED, that rebuilding has already happened (a generated
// struct's own `from_json`/mutation-application built the nested value
// ahead of time) — what this file owns is reading it back:
// `Resolver#fetch`'s own recursive per-segment walk (resolver.rb), one
// dotted-path component at a time, mirrored here as the `Field::Nested`
// half of every `Field` a dotted `Lookup` path can resolve to
// (`expr.rs`'s `lookup`, which calls straight into `step`/`finish`
// below rather than walking `Field` itself).

use crate::kernel::expr::{eval_error, Field, Value};
use crate::kernel::Refusal;

/// One segment further into a nested value object — `obj.field(seg)`,
/// Ruby's own recursion inside `Resolver#fetch`. `head` (the FIRST path
/// segment) is carried through only for the "no such nested field"
/// wording; `path` (the WHOLE dotted string) only for "the field so far
/// isn't an object to walk further into" — matching `lookup`'s own two
/// distinct messages exactly.
pub fn step<'a>(current: Field<'a>, seg: &str, head: &str, path: &str) -> Result<Field<'a>, Refusal> {
    match current {
        Field::Nested(obj) => obj.field(seg).ok_or_else(|| eval_error(format!("cannot resolve {seg:?} on {head:?}"))),
        Field::Value(v) => Err(eval_error(format!("{path} — cannot look up {seg:?} on scalar {v:?}"))),
        // A LIST HAS NO NAMED FIELD OF ITS OWN TO WALK — "fix the gaps,
        // continued." `.first`/`.last`/`.all?`/`.any?`/`.none?`/`.find`
        // are the real way into a list's elements, and every one of
        // them is grammar-terminal or carries its own explicit `path`
        // (`Find`'s own struct) rather than composing through an
        // ordinary dotted `Lookup` segment the way this function walks
        // — so an ordinary segment landing on a `NestedList` here is
        // exactly as much a real refusal as one landing on a scalar,
        // just above.
        Field::NestedList(_) => {
            Err(eval_error(format!("{path} — cannot look up {seg:?} on a list; use .first/.last/.all?/.any?/.none?/.find instead")))
        }
    }
}

/// The path has run out of segments — `current` is either the scalar the
/// whole dotted path resolved to (the ordinary case, every real corpus
/// `Lookup`), or still a nested object (a path that names a value object
/// or a dereferenced reference itself rather than one of its own
/// fields). `Fielded::as_scalar` (expr.rs) is that object's own OPTIONAL
/// "collapse me to a comparable scalar" reading — `DerefNode`'s own
/// override (`reference_lookup.rs`) is the real, live example (`source
/// != destination`); everything else still answers `None`, so a bare
/// nested-VO lookup this corpus never actually needs still refuses the
/// same way it always has, rather than silently returning something no
/// `Expr` variant expects.
pub fn finish(current: Field<'_>, path: &str) -> Result<Value, Refusal> {
    match current {
        Field::Value(v) => Ok(v),
        Field::Nested(obj) => obj.as_scalar().ok_or_else(|| eval_error(format!("{path} resolved to an object, not a scalar"))),
        // Every ordinary caller (`.size`/`.empty?`/`.present?`/
        // `.blank?`/comparisons — everything that reaches `Value`
        // through `lookup`/`interpret` rather than
        // `expr::interpret_as_field`) only ever needs the count, same
        // as before this pass — real element access lives behind
        // `interpret_as_field` instead, which returns the `Field`
        // itself and never calls this function at all.
        Field::NestedList(list) => Ok(Value::List(list.list_len())),
    }
}
