---
title: Arithmetic mangling
description: Rewrites additions and multiplications into equivalent, harder-to-read expressions.
layout: docs
---

<PassFacts pass="arith" />

## What it does

A formula in readable form tells a reader what the code computes. This pass
rewrites integer additions and multiplications into expressions that compute
the same number the long way round: `a + b` becomes `(a ^ b) + ((a & b) << 1)`,
and `a * b` becomes `a * (b + k) - a * k` for some constant `k`. The value
doesn't change; what a reader or a decompiler sees does.

<PassAnimation pass="arith" />

## Example

`a + b` becomes the XOR/AND identity and `sum * n` is split around a constant; both still compute the same number.

<PassCompare pass="arith">

```dart
int cost(int a, int b, int n) {
  final sum = a + b;
  return sum * n;
}
```

```dart
int cost(int a, int b, int n) {
  final sum =
      (a ^ b) + ((a & b) << 1);
  return sum * (n + 7) - sum * 7;
}
```

</PassCompare>

## What it changes

- `+` and `*` in your project's code when both operands are integers and the
  result is an `int`, including loop increments like `i = i + 1`.
- Nested expressions, from the inside out, so a longer formula is mangled all
  the way through.

## What it leaves alone

- Other operators, such as `-`, `~/` and `%`.
- Floating-point math and mixed `num` expressions, to avoid any change in
  rounding.
- Arithmetic in a `const` context.
- Code kept with `exclude` or `@Refractor.keep()`.

## Configuration

```yaml
refractor:
  passes:
    arithmetic_mangle: true
```

| Option | Type | Default | Meaning |
|---|---|---|---|
| `seed` | int | `0x0A17` | Seeds which identity and constant each expression gets, for reproducible builds. |

`enabled` and `exclude` work as on every pass; see
[Configuration](/guide/configuration#pass-options).

## Cost and strength

**Cost.** About 0.3 nanoseconds per mangled operation in a native executable on
an Apple-silicon Mac, measured over a hundred million loop iterations, and a
few dozen bytes of code for each. Mangled loop counters pay it on every
iteration.

**Strength.** The compiler doesn't undo it: in a disassembly of the built
executable the XOR, AND and shift sequence is still there, and so is the split
multiplication. The constants stay readable, though. In `a * (b + k) - a * k`
the compiler folds `b + k` when `b` is a constant, so subtracting the two
numbers left in the code gives `b` back. List
[integer encryption](/rulebook/int-encryption) after this pass to hide them.

## Guarantees & limitations

<Guarantees>
<Promises>

- The rewrites are exact identities over Dart's 64-bit integers, so results don't change.
- An operand with side effects is stored in a temporary first, so `f() + g()` still calls each function once.

</Promises>
<Caveats>

- Only `+` and `*` on integers are touched. Doubles and mixed `num` expressions are left alone to avoid any change in rounding.
- The constants it introduces are plain numbers unless integer encryption runs after it.

</Caveats>
</Guarantees>

## Works with

- **Integer encryption.** Listed after this pass in `refractor.yaml`, it also
  encrypts the constants mangling adds; listed before, those stay readable.
  Passes run in the order they're listed.
- **String encryption.** The string decoder's own arithmetic gets mangled too,
  since the decoder is part of your program by the time the passes run.

<PassPager pass="arith" />
