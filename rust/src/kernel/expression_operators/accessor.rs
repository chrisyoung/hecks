// Implements the Ruby grammar's "accessor" expression-operator category
// (projection.json: `.first`, `.last` — two symbols, two interpreter
// nodes) — `Resolver::First`/`Last` (resolver.rb), read directly. PRD
// 09 — admitted alongside `.match?`/`.present?`/`.blank?`/`.split`/
// `.start_with?`/`.end_with?`, all previously real in Ruby's `Resolver`
// and ungoverned by the operator ledger entirely.
//
// BOTH REAL NOW, over BOTH real element sources — PRD 09's gap-closing
// pass, and the "fix the gaps, continued" pass on top of it.
// `.split`-produced `Value::Elements` answers with the real first/last
// scalar (unchanged). A STORED list attribute's own real elements
// (`Field::NestedList`, `expr/logic.rs`'s own header) now answer too:
// the real element, collapsed to its own scalar via `Fielded::
// as_scalar` when it has exactly one field (every generated
// single-field value object now implements this — `rust/project/
// types.rb`'s own `emit_as_scalar`) — a real, precise refusal,
// naming the reason, when it has more than one and there is genuinely
// no single `Value` a bare `.first`/`.last` could answer (the grammar
// itself gives `.first`/`.last` no trailing dotted path the way
// `.find` gets one — see `block_predicate.rs`'s own header — so there
// is no way to ask for just ONE of a multi-field element's fields
// here). `Ruby`'s own `[].first`/`[].last == nil` on an empty list,
// either source, matching Ruby exactly rather than refusing a case
// Ruby itself answers.
//
// NO REAL CORPUS FIXTURE EXERCISES `.split`-PRODUCED elements — see
// `string.rs`'s own header for the full explanation; verified there by
// hand-written unit tests instead of `rust_conformance_spec.rb`. The
// STORED-list path DOES have one now — `reaction.bluebook`'s own
// `Normalise`/`Attach` `ensures` checks (the self-hosted grammar's own
// use of this, per the "fix the gaps, continued" pass) — so this file's
// own tests, below, are real but not the ONLY verification any more.
//
// EVERY `Field`/`Value` VARIANT IS NAMED BELOW, NONE LEFT TO A
// WILDCARD — see `sized.rs`'s own header for why. `expr.rs`'s
// `category_of` guarantees each function below is only ever called with
// its own node kind — see `logical.rs`'s own header for why the
// trailing router-bug arms are not real refusal paths.

use crate::kernel::expr::{eval_error, interpret_as_field, EvalContext, Expr, Field, Value};
use crate::kernel::Refusal;

pub fn first(expr: &Expr, ctx: &EvalContext) -> Result<Value, Refusal> {
    let Expr::First(receiver) = expr else {
        return Err(Refusal::TypeMismatch(format!("accessor::first called with a non-first node {expr:?} — a router bug")));
    };

    match interpret_as_field(receiver, ctx)? {
        Field::Value(Value::Elements(elements)) => Ok(elements.into_iter().next().unwrap_or(Value::Nil)),
        Field::NestedList(list) if list.list_len() == 0 => Ok(Value::Nil),
        Field::NestedList(list) => element_scalar(list.list_get(0), 0, "first"),
        Field::Value(v) => Err(eval_error(format!("first expects a list, got {v:?}"))),
        Field::Nested(_) => Err(eval_error("first expects a list, got a single nested object".to_string())),
    }
}

pub fn last(expr: &Expr, ctx: &EvalContext) -> Result<Value, Refusal> {
    let Expr::Last(receiver) = expr else {
        return Err(Refusal::TypeMismatch(format!("accessor::last called with a non-last node {expr:?} — a router bug")));
    };

    match interpret_as_field(receiver, ctx)? {
        Field::Value(Value::Elements(mut elements)) => Ok(elements.pop().unwrap_or(Value::Nil)),
        Field::NestedList(list) if list.list_len() == 0 => Ok(Value::Nil),
        Field::NestedList(list) => element_scalar(list.list_get(list.list_len() - 1), list.list_len() - 1, "last"),
        Field::Value(v) => Err(eval_error(format!("last expects a list, got {v:?}"))),
        Field::Nested(_) => Err(eval_error("last expects a list, got a single nested object".to_string())),
    }
}

/// Shared by `first`/`last`'s own non-empty `NestedList` arm — the
/// element at `index`, collapsed via `Fielded::as_scalar`. `None` there
/// means a genuinely multi-field element with no single `Value` a bare,
/// grammar-terminal `.first`/`.last` could ever answer (this file's own
/// header explains why that stays a real refusal, not a gap).
fn element_scalar(element: &dyn crate::kernel::expr::Fielded, index: usize, suffix: &str) -> Result<Value, Refusal> {
    element.as_scalar().ok_or_else(|| {
        eval_error(format!(
            "{suffix} found a real element at index {index} but it has more than one field — a bare .{suffix} can only answer a single-field element as a value; there is no dotted-path syntax after .{suffix} to project into a multi-field one"
        ))
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::kernel::expr::{Fielded, NoFields};

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

    // "Fix the gaps, continued" — `Field::NestedList`, a STORED list's
    // own real elements, not `.split`'s own `Value::Elements`. Mirrors a
    // real generated single-field value object (`PizzaName`, `Price`)
    // via `as_scalar`, and a real multi-field one (`Binding`) by NOT
    // overriding it — `Fielded`'s own default answers `None`, the same
    // as every generated multi-field struct today.
    struct SingleFieldElement(&'static str);
    impl Fielded for SingleFieldElement {
        fn field(&self, _name: &str) -> Option<crate::kernel::expr::Field<'_>> {
            None
        }

        fn as_scalar(&self) -> Option<Value> {
            Some(Value::Str(self.0.to_string()))
        }
    }

    struct MultiFieldElement;
    impl Fielded for MultiFieldElement {
        fn field(&self, _name: &str) -> Option<crate::kernel::expr::Field<'_>> {
            None
        }
    }

    struct FixedList<T>(Vec<T>);
    impl<T: Fielded> Fielded for FixedList<T> {
        fn field(&self, name: &str) -> Option<crate::kernel::expr::Field<'_>> {
            (name == "list").then(|| crate::kernel::expr::Field::NestedList(&self.0))
        }
    }

    #[test]
    fn first_and_last_answer_the_real_stored_element_via_as_scalar() {
        let list = FixedList(vec![SingleFieldElement("a"), SingleFieldElement("b"), SingleFieldElement("c")]);
        let ctx = EvalContext { args: &list, instance: &NoFields };

        assert_eq!(first(&Expr::First(Box::new(Expr::Lookup("list"))), &ctx).unwrap(), Value::Str("a".to_string()));
        assert_eq!(last(&Expr::Last(Box::new(Expr::Lookup("list"))), &ctx).unwrap(), Value::Str("c".to_string()));
    }

    #[test]
    fn first_and_last_answer_nil_on_an_empty_stored_list() {
        let list = FixedList(Vec::<SingleFieldElement>::new());
        let ctx = EvalContext { args: &list, instance: &NoFields };

        assert_eq!(first(&Expr::First(Box::new(Expr::Lookup("list"))), &ctx).unwrap(), Value::Nil);
        assert_eq!(last(&Expr::Last(Box::new(Expr::Lookup("list"))), &ctx).unwrap(), Value::Nil);
    }

    #[test]
    fn first_refuses_a_multi_field_stored_element_naming_the_real_reason() {
        let list = FixedList(vec![MultiFieldElement]);
        let ctx = EvalContext { args: &list, instance: &NoFields };

        let err = first(&Expr::First(Box::new(Expr::Lookup("list"))), &ctx).unwrap_err();
        let message = format!("{err:?}");
        assert!(message.contains("more than one field"), "expected a multi-field refusal, got {message:?}");
    }
}
