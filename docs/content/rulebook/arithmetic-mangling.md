---
title: Arithmetic mangling
description: Rewrites integer + and * into equivalent but harder-to-read expressions.
layout: docs
---

<PassFacts pass="arith" />

## What it does

Arithmetic mangling rewrites integer additions and multiplications into
expressions that compute the same number the long way round. `a + b` becomes
`(a ^ b) + ((a & b) << 1)`, and `a * b` becomes `a * (b + k) - a * k` for some
constant `k`. The value doesn't change; what a reader or a decompiler sees
does.

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

## What it targets

It rewrites `+` and `*` in your project's code when both operands are integers
and the result is an `int`. Nested expressions are rewritten from the inside out,
so a longer formula is mangled all the way through. Floating-point math and
arithmetic in `const` contexts are left alone.

It follows `exclude` globs and `@Refractor.keep()`, like every pass.

## Configuration

<Tabs defaultValue="minimal">
<TabItem label="Minimal" value="minimal">

```yaml
refractor:
  passes:
    arithmetic_mangle: true
```

</TabItem>
<TabItem label="All options" value="all">

```yaml
refractor:
  passes:
    arithmetic_mangle:
      enabled: true
      seed: 0x0A17    # default
      exclude: []     # extra library globs
```

</TabItem>
</Tabs>

| Option | Type | Default | Meaning |
|---|---|---|---|
| `enabled` | bool | `true` | Turns the pass on or off. |
| `exclude` | glob list | `[]` | More libraries for this pass to skip, on top of the global `exclude`. |
| `seed` | int | `0x0A17` | Seeds which identity and constant each expression gets, for reproducible builds. |

## Guarantees & limitations

<Guarantees>
<Promises>

- The rewrites are exact identities over Dart's 64-bit integers, so results don't change.
- An operand with side effects is stored in a temporary first, so `f() + g()` still calls each function once.

</Promises>
<Caveats>

- Only integer math is touched. Doubles and mixed `num` expressions are left alone to avoid any change in rounding.

</Caveats>
</Guarantees>

## Output

The build report counts `operations_mangled`.

<PassPager pass="arith" />
