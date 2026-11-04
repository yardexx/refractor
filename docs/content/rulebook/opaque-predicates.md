---
title: Opaque predicates
description: Joins an always-true check to your if conditions.
layout: docs
---

<PassFacts pass="opaque" />

## What it does

A plain `if` condition tells a reader exactly when a branch runs. This pass
joins an extra check to each one, so `if (c)` becomes `if (c && check)`. The
check is always true, though that isn't obvious from reading it, so the
original condition still decides which branch runs.

<PassAnimation pass="opaque" />

## Example

`n` is the nearest `int` in scope, so the predicate is keyed off it. A masked square is never negative, so the branch still depends only on `o.isPaid`.

<PassCompare pass="opaque">

```dart
void refund(Order o, int n) {
  if (o.isPaid) {
    issueRefund(o, n);
  }
}
```

```dart
void refund(Order o, int n) {
  if (o.isPaid &&
      (n & 0xFFFF) * (n & 0xFFFF) >= 0) {
    issueRefund(o, n);
  }
}
```

</PassCompare>

## What it changes

- Every `if` statement in your project's code outside a `const` context,
  including those in getters and `async` functions.
- Where a safe `int` variable is in scope, the check reads it:
  `(n & 0xFFFF) * (n & 0xFFFF) >= 0`. Safe means a non-nullable parameter, or
  a local that has an initialiser and isn't `late` or `const`, so the variable
  always has a value at the `if`. Where there's none, the check is built from
  constants, such as `k * k >= k`.

## What it leaves alone

- Conditional expressions (`?:`) and loop conditions.
- Code kept with `exclude` or `@Refractor.keep()`.

## Configuration

```yaml
refractor:
  passes:
    opaque_predicate: true
```

| Option | Type | Default | Meaning |
|---|---|---|---|
| `seed` | int | `0x05A1` | Seeds which variable and, for checks built from constants, which template and constant each condition gets. |

`enabled` and `exclude` work as on every pass; see
[Configuration](/guide/configuration#pass-options).

## Cost and strength

**Cost.** Small. The check only runs when the original condition is true, so in
a typical hot loop the difference was within measurement noise. In the worst
case, a condition that is always true in a tight loop that the compiler
inlines, it added about a third. Each strengthened condition adds about 30
bytes of code.

**Strength.** Only checks that read a variable survive into a native build.
Checks built from constants are folded away by the AOT compiler, and so are
variable checks when the compiler can work out the variable's value. The
checks that do survive all share one shape, the masked square, so once a
reader has seen one they can spot the rest.

## Guarantees & limitations

<Guarantees>
<Promises>

- The added check is always true, so the original condition alone picks the branch.
- The check runs only after the original condition, so it can't change which side effects happen.

</Promises>
<Caveats>

- It only strengthens conditions that are already there. It doesn't add or reorder control flow; [control-flow flattening](/rulebook/control-flow-flatten) and [bogus control flow](/rulebook/bogus-control-flow) do that.

</Caveats>
</Guarantees>

## Works with

- **Dead code and bogus control flow.** List this pass before them in
  `refractor.yaml`. Listed after, it strengthens their guards too, which
  produces visibly contradictory checks such as `x < 0 && x >= 0`. Passes run
  in the order they're listed.
- **Integer encryption.** Listed after this pass, it encrypts the `0xFFFF`
  masks and constants in the checks.

<PassPager pass="opaque" />
