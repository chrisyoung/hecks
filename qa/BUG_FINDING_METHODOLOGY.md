# Bug-Finding Methodology for hecksagain

**Developed:** 2026-08-11 via adversarial testing
**Result:** Found 3 bugs, fixed 1, documented 2

---

## Core Approach: Adversarial Testing

The key principle: **Start with an expectation, then try to violate it.**

Instead of testing "happy paths", I intentionally attack the system from multiple angles:

---

## Testing Categories

### 1. **Boundary Testing**
Tests extreme or edge-case values:
```ruby
# What's the smallest valid value?
{ cents: 0 }        # Should fail but doesn't (nested VO bug)
{ cents: -100 }     # Should fail but doesn't
{ cents: 1 }        # Should pass ✓

# What's the longest valid string?
{ name: "" }        # Empty string (works because direct VOs ARE validated)
{ name: "A" * 10000 }  # Very long string
```

**Bug Found:** Zero/negative prices accepted (nested VO invariant validation gap)

---

### 2. **Empty/Null Testing**
Tests absence and emptiness:
```ruby
{ value: "" }       # Empty string
{ value: nil }      # Null/missing
{ topping: "" }     # Empty topping name
```

**Result:** Direct VOs properly reject empty strings; nested ones don't

---

### 3. **State Violation Testing**
Tests invalid state transitions:
```ruby
# Command after command
purchase()
purchase()          # Second purchase on same pizza - should fail ✓

# Mutation after lifecycle change
purchase(pizza)
add_topping(pizza)  # Modify sold pizza - should fail ✓

# Invalid order of operations
add_topping(pizza)
purchase()          # Without at least 1 topping - should fail ✓
```

**Result:** State guards working correctly ✓

---

### 4. **Mutation/Immutability Testing**
Tests if returned state can be mutated:
```ruby
result = purchase(pizza)
result.state[:toppings] << { malicious: "injection" }

# Question: Is the array frozen?
result.state[:toppings].frozen?  # false = BUG!
```

**Bug Found:** Lists not frozen - users can corrupt persisted state ✓ FIXED

---

### 5. **Identity/Collision Testing**
Tests uniqueness and ID handling:
```ruby
# SQL injection-like attempts
{ name: "'; DROP TABLE; --" }

# Non-existent aggregates
add_topping(name: "fake-pizza-id")

# Duplicate references
Transfer.Request(reference: "xfer-1")
Transfer.Request(reference: "xfer-1")  # Should fail ✓
```

**Result:** SQL injection handled safely via pattern validation

---

### 6. **Type Coercion Testing**
Tests type mismatches:
```ruby
# Wrong type passed
{ price_cents: { cents: "abc" } }     # String instead of int
{ amount: { value: 0.5 } }            # Float instead of int

# Missing required fields
{ price_cents: {} }                   # Missing cents field
```

**Result:** Type validation working (pattern matching on email)

---

### 7. **Rapid Mutation Stress Testing**
Tests order-of-operations under load:
```ruby
# Add many toppings quickly
8.times do |i|
  dispatch("AddTopping", ...)
end

# Verify:
# - All toppings present
# - Order preserved
# - No data loss
# - Events recorded correctly
```

**Result:** Event ordering maintained, no data loss ✓

---

### 8. **Special Character Testing**
Tests encoding and escaping:
```ruby
{ name: "🍕 Unicode Pizza" }          # Unicode
{ name: "O'Reilly's & Co." }          # Quotes, ampersand
{ name: "'; DROP TABLE; --" }         # SQL-like
```

**Result:** All handled safely ✓

---

## How I Found Bugs

### **Bug #1: Nested VO Invariants Not Validated**

**Discovery Process:**
1. Saw that `ToppingAmount { value: 0 }` was rejected ✓
2. Tested `Price { cents: 0 }` nested in Pizza
3. Expected rejection, got acceptance → **BUG**
4. Isolated: Direct VOs work, nested ones don't
5. Root cause: `Value::Coercion.build()` only validates top-level VOs

### **Bug #2: Invalid Closed-Set Values Accepted**

**Discovery Process:**
1. Tested Size closed set with valid values: small, large
2. Tried invalid value: medium
3. Expected rejection, got acceptance → **BUG**
4. Root cause: Same as #1 (nested in Pizza value object)

### **Bug #3: List Attributes Mutable (FIXED)**

**Discovery Process:**
1. Got result from `Purchase` command
2. Accessed `result.state[:toppings]`
3. Tried to mutate: `array << { injected: true }`
4. Expected FrozenError, mutation succeeded → **BUG**
5. Root cause: Arrays not frozen when returned
6. Fixed by adding `.freeze` at materialization points

---

## Why This Approach Works

1. **Systematic Coverage** - Tests don't just check happy paths
2. **Expectation-Driven** - Start with what SHOULD happen
3. **Cascading** - One bug discovery often reveals others
4. **Reproducible** - Each test is a concrete reproducible case
5. **Fixable** - Can distinguish between design vs. implementation bugs

---

## Testing Tools Created

### qa_adversarial.rb
Comprehensive adversarial test patterns covering all 8 categories above

### qa_runner.rb  
Automated corpus structure validator - ensures test data is well-formed

### qa_regression_checks.rb
Regression patterns for known fixes to prevent re-introduction

### qa_empty_string_regression_test.rb
Focused tests on specific validation patterns

---

## Key Insights

1. **Direct VOs work, nested ones fail**
   - Invariants validated on top-level values
   - NOT validated when nested inside other VOs
   - Design issue in `Value::Coercion`

2. **State is mutable by default**
   - Arrays/hashes returned from dispatch are not frozen
   - Allows accidental (or malicious) corruption
   - Fix: Freeze at all materialization points

3. **Test what you forbid, not just what you allow**
   - Testing refusal paths is as important as success paths
   - The "no empty strings" invariant only matters if tested with empty strings

4. **Watch for cascading validation gaps**
   - One missing validation (nested VOs) causes multiple apparent bugs
   - Fixed root cause could eliminate multiple symptoms

---

## Methodology Applied to Other Domains

This same approach applies to any domain:

**Banking Example:**
- Boundary: negative amounts, zero amounts ✓
- Empty: empty customer names, empty account numbers
- State: double-reversals, reversing twice
- Mutation: are balances immutable after operations?
- Identity: duplicate transfer references
- Type: wrong currency codes
- Stress: many rapid transfers
- Encoding: special characters in narrative

**Any Domain:**
1. List the invariants declared in bluebook
2. For each invariant, test the boundary:
   - Just inside (valid): ✓
   - Just outside (invalid): X should fail
   - Edge cases: 0, empty, negative, max
3. Test violations of state rules
4. Test if returned state is properly immutable
5. Test rapid mutations of the same aggregate

---

## When to Stop Testing

- When you've hit all 8 categories
- When you've found something you CAN fix
- When further testing requires runtime changes (stop, document, mark as known)

**This methodology balances thoroughness with practicality.**
