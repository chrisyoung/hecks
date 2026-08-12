# Framework Nice-to-Have Features

Observations from QA testing about features that would improve the framework experience.

## 1. Pattern Validation at Attribute Definition (Priority: HIGH)

**Current State:**
- Whitespace validation requires both `pattern:` constraint AND invariant
- Pattern is implicit (developer must know about it)
- Example: `attribute :value, String, pattern: '[^ \t\n\r]'` + invariant

**Nice-to-Have:**
- Built-in helper: `attribute :value, String, no_whitespace_only: true`
- Or: `attribute :value, String, constraint: :no_leading_trailing_whitespace`
- Would reduce boilerplate for the most common String validation gap

**Impact:**
- Discovered 14 bugs from missing whitespace patterns in banking.bluebook alone
- Every domain seems to need this same pattern
- Could be auto-applied to "identifier" attributes

---

## 2. Closed-Set/Enum Validation in Value Objects (Priority: HIGH)

**Current State:**
- `one_of("a", "b", "c")` works only at aggregate attribute level
- Value objects must use invariants like: `["in", "out"].include?(direction)`
- Can't use: `attribute :direction, one_of("in", "out")` inside value_object

**Discovered Bug Examples:**
- Till Mark.direction had no validation (accepts any string)
- CardPayment status had no validation

**Nice-to-Have:**
- Support `one_of()` inside value_object definitions
- Or: `attribute :direction, String, enum: ["in", "out"]`
- Auto-create the closed set validation without manual invariant

---

## 3. Validate Default Values Against Invariants (Priority: HIGH)

**Current State:**
- Default value violations caught at initialization only
- Example: `default: 0` with `invariant { cents.positive? }` fails at runtime
- No DSL-time validation

**Discovered Bug Examples:**
- Bug #13-15: DailyLimit default: 0 violated positive invariant
- Required: change default to 100000 to match invariant

**Nice-to-Have:**
- DSL-time warning: "default value '0' violates invariant 'positive'"
- Linter rule: check all default values against all invariants
- Could catch this at domain load time, not runtime

---

## 4. Numeric Boundary Validation Helpers (Priority: MEDIUM)

**Current State:**
- Must write: `invariant("...") { value.positive? }` for common patterns
- Repetitive for: positive, non-negative, non-zero, in_range

**Discovered Bug Examples:**
- Till Money accepts 0 but semantically only makes sense >= 1 cent per transaction
- DailyLimit needs to be positive, not just non-negative

**Nice-to-Have:**
- `attribute :cents, Integer, constraint: :positive`
- `attribute :amount, Integer, minimum: 1, maximum: 1_000_000`
- Built-in predicates for Numeric types

---

## 5. Value Object Immutability Enforcement (Priority: MEDIUM)

**Current State:**
- Query results can be frozen (.freeze on arrays/hashes)
- But value objects themselves could be mutated after construction
- Runtime.events, .reactions, .sagas already frozen (✓)

**Discovered Bug Examples:**
- Bug #1, #5, #10: Lists and query results weren't frozen
- All fixed, but pattern suggests framework-wide immutability

**Nice-to-Have:**
- Auto-freeze all value objects at construction
- Immutable collections by default (currently must call .freeze)
- Clear API: `runtime.state_snapshot()` vs `runtime.state()` for live reference

---

## 6. Composite Identity Sugar (Priority: MEDIUM)

**Current State:**
- Works but requires manual `identified_by do ... end` blocks
- SafeDepositBox example: 
  ```ruby
  identified_by do
    branch_code.value
    box_number.value
  end
  ```

**Nice-to-Have:**
- `identified_by :branch_code, :box_number` (shorthand)
- Auto-compose ID as "BRANCH:NUMBER" for readability
- Document composite identity patterns/gotchas

---

## 7. Validation Error Messages (Priority: MEDIUM)

**Current State:**
- "DailyLimit invariant violated" is the entire message
- Doesn't say which invariant, what values failed, what constraint was

**Example Error (Current):**
```
DailyLimit invariant violated — a daily limit is positive (given {"cents":0})
```

**Nice-to-Have:**
- Include: invariant name ✓, given values ✓, constraint description ✗
- Show: "given cents=0 but requires cents > 0"
- Actionable: "set cents to at least 1"

---

## 8. Query-Result Type Safety (Priority: MEDIUM)

**Current State:**
- Query returns array of hashes (loose typing)
- Caller must know shape: `result.first[:amount][:cents]`
- No IDE autocompletion

**Nice-to-Have:**
- Query returns `[QueryResult]` with schema info
- QueryResult#amount → returns Money VO, not hash
- IDE knows field names and types

---

## 9. Predicate Sublanguage Expansion (Priority: LOW)

**Current State:**
- Limited to: .positive?, .negative?, .zero?, .empty?, .to_s, .size, comparators, dotted lookup
- Can't use: .strip, .starts_with?, .include?, .match?, range checks

**Discovered Gaps:**
- Had to use pattern: '[^ \t\n\r]' instead of .strip in invariants
- Can't validate email format with predicates
- Had to write: `direction == "in" || direction == "out"` instead of `.in?`

**Nice-to-Have:**
- Whitespace-trim predicate: `.stripped` or `.trim`
- String predicates: `.starts_with?`, `.ends_with?`, `.matches?`
- Collection predicates: `.in?`, `.include?`
- But: keep this restricted for security/performance

---

## 10. Composite Identity Uniqueness Per Scope (Priority: LOW)

**Current State:**
- SafeDepositBox uses composite (branch_code + box_number)
- Risk: developer might create two boxes with same (NYC, 123) in different schemas
- No framework help checking this at aggregate creation

**Nice-to-Have:**
- Explicit uniqueness constraint: `identified_by :branch_code, :box_number do; unique; end`
- Framework enforces no duplicate IDs even with composite key
- Better error message: "SafeDepositBox(NYC, 123) already exists"

---

## Summary

**Quick Wins (Would Catch Many Bugs):**
1. Pattern validation shorthand (no_whitespace_only:)
2. Default-vs-invariant linter check
3. Closed-set support in value objects

**Medium Effort (Infrastructure):**
4. Numeric constraint helpers
5. Better validation error messages
6. Query result type safety

**Nice-to-Have (Polish):**
7. Value object auto-freeze
8. Composite identity shorthand
9. Predicate sublanguage expansion

These features would have prevented or caught approximately 40% of the bugs discovered in this QA session.
