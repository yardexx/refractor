> **SUPERSEDED** — The dead_code pass this feature was designed for has been removed. The Dart VM's CFG optimizer eliminates all dead branches regardless of predicate complexity when the branch body has no observable side effects. See [optimization-resistance.md](optimization-resistance.md). This document is retained for reference — opaque predicates remain valid building blocks for future passes (bogus control flow with cloned code, CFF state guards).

# Feature Request: Opaque Predicate Generator

## Summary

Add an opaque predicate generator that produces conditions whose results are known at obfuscation time but are difficult for static analysis to resolve. This replaces the trivially-detectable `BoolLiteral(false)` in the dead code pass and serves as a building block for future passes (bogus control flow, control flow flattening guards).

## Motivation

The current `dead_code` pass inserts `if (false) { ... }` branches. `BoolLiteral(false)` is a compile-time constant that any decompiler or the Dart AOT compiler itself eliminates immediately. The dead branches literally vanish from compiled output, providing zero obfuscation value.

Opaque predicates fix this by making the condition appear non-trivial to static analysis while still being deterministic at runtime.

## Design

### Separate module, not embedded in a pass

The generator lives in `lib/src/engine/passes/opaque_predicate/` as a standalone utility that any pass can import. This avoids coupling predicate logic to dead_code and enables reuse by future passes (bogus control flow, control flow flattening).

```
lib/src/engine/passes/opaque_predicate/
  opaque_predicate_generator.dart   -- main generator class
  strategies/
    allocation_identity.dart        -- identical([], [])
    number_theory.dart              -- (x*(x+1)) % 2 != 0, etc.
    collatz.dart                    -- Collatz convergence check
```

### Generator API

```dart
/// Generates opaque predicate expressions for use in kernel AST.
class OpaquePredicateGenerator {
  OpaquePredicateGenerator({
    required this.coreTypes,
    required this.identicalProcedure,
    required Random random,
  });

  /// Returns an [Expression] that always evaluates to [value] at runtime.
  Expression generate({required bool value});
}
```

The generator randomly selects a strategy on each call to avoid producing structurally identical predicates.

### Predicate Strategies

#### 1. Allocation Identity (always false)

```dart
identical(<int>[], <int>[])   // two fresh allocations are never identical
```

- **Strength**: Cannot be resolved without heap modelling.
- **Runtime cost**: Two list allocations per evaluation. Negligible for low-frequency insertion.
- **Kernel AST**: `StaticInvocation(identical, [ListLiteral([]), ListLiteral([])])`.
- **Inversion** (always true): `!identical(<int>[], <int>[])` via `Not(StaticInvocation(...))`.

#### 2. Number Theory (always false)

```dart
(x * (x + 1)) % 2 != 0   // product of consecutive ints is always even
```

Where `x` is a runtime-derived value (e.g., `DateTime.now().microsecondsSinceEpoch`).

- **Strength**: Requires modular arithmetic reasoning to resolve statically.
- **Runtime cost**: Arithmetic + one `DateTime.now()` call.
- **Variants**:
  - `(x * x + x) % 2 != 0` (equivalent, different shape)
  - `(x * x * x - x) % 3 != 0` (always false — `x^3 - x = x(x-1)(x+1)`, product of 3 consecutive ints)
  - `(x * x) % 4 == 2` (always false — squares mod 4 are 0 or 1, never 2)
- **Inversion** (always true): Flip the comparison operator.

#### 3. Collatz Convergence (always true)

```dart
int n = <small runtime seed>;
while (n != 1) {
  n = n.isEven ? n ~/ 2 : 3 * n + 1;
}
n == 1  // always true (Collatz conjecture, verified for all practical values)
```

- **Strength**: Resolving statically is equivalent to proving the Collatz conjecture (open problem).
- **Runtime cost**: Variable — depends on seed. Seeds 2-100 converge in <120 steps. Use small seeds.
- **Trade-off**: Highest analysis resistance but highest runtime cost. Use sparingly.
- **Inversion** (always false): `n != 1` after convergence.

### Configuration

```yaml
dead_code:
  enabled: true
  max_insertions_per_procedure: 2
  predicate_strategies:
    - allocation_identity
    - number_theory
    - collatz                    # optional, off by default due to runtime cost
```

If no strategies are specified, defaults to `[allocation_identity, number_theory]`.

### Integration with Dead Code Pass

The `DeadCodeTransformer` currently creates `IfStatement(BoolLiteral(false), ...)`. After this feature:

```dart
// Before:
IfStatement(BoolLiteral(false), deadBlock, null)

// After:
IfStatement(generator.generate(value: false), deadBlock, null)
```

The transformer receives an `OpaquePredicateGenerator` instance from the pass. No other changes needed.

## Testing

- **Unit tests per strategy**: Verify each strategy produces valid kernel expressions that evaluate to the expected boolean.
- **Round-trip test**: Compile a program with opaque predicates, run it, assert output matches non-obfuscated version.
- **Randomness test**: Generate N predicates, assert structural variation (not all identical AST shapes).

## Future Use

- **Bogus control flow**: Use `generate(value: true)` to guard real code branches, `generate(value: false)` for cloned decoy branches.
- **Control flow flattening**: Use opaque predicates in state transition guards to obscure dispatch logic.
- **Guard conditions**: Wrap sensitive code sections with opaque true predicates that appear to be runtime checks.

## Dependencies

- `dart:core` library resolution (already done in `dead_code_pass.dart` for `identical`)
- `dart:math` `Random` for strategy selection and seed generation
- Core types from kernel `Component` for constructing typed expressions

## Priority

P1 (quick win) per `docs/v0.2-goals.md`. Low implementation effort, high obfuscation value improvement over current `BoolLiteral(false)`.
