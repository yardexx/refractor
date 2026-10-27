---
title: Opaque predicates
description: Adds always-true checks to your if conditions, built from live variables.
layout: docs
---

<PassFacts pass="opaque" />

## What it does

Opaque predicates make your existing `if` conditions harder to reason about.
Each condition gets an extra check that is always true, though that isn't obvious
from reading it. The check reads a variable that is live at that point, so the
compiler can't prove it constant and remove it, and the original condition still
decides which branch runs.

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

## What it targets

It works on `if` statements in your project's code outside `const` contexts.
For each one it picks the nearest `int` in scope, a parameter or a local, and
builds the check from it. Where there's no `int` in scope, it falls back to a
check built from constants.

It follows `exclude` globs and `@Refractor.keep()`, like every pass.

## Configuration

<Tabs defaultValue="minimal">
<TabItem label="Minimal" value="minimal">

```yaml
refractor:
  passes:
    opaque_predicate: true
```

</TabItem>
<TabItem label="All options" value="all">

```yaml
refractor:
  passes:
    opaque_predicate:
      enabled: true
      seed: 0x05A1    # default
      exclude: []     # extra library globs
```

</TabItem>
</Tabs>

| Option | Type | Default | Meaning |
|---|---|---|---|
| `enabled` | bool | `true` | Turns the pass on or off. |
| `exclude` | glob list | `[]` | More libraries for this pass to skip, on top of the global `exclude`. |
| `seed` | int | `0x05A1` | Seeds which template and which variable each condition uses, for reproducible builds. |

## Guarantees & limitations

<Guarantees>
<Promises>

- Behaviour doesn't change: the added check is always true, so the original condition alone picks the branch.
- The check reads a live variable (for example, a masked square that can never be negative), so the optimizer can't drop it.
- The `seed` varies the template and the variable from one condition to the next, so the added checks don't all look alike.

</Promises>
<Caveats>

- It only strengthens conditions that are already there. It doesn't add or reorder control flow; [control-flow flattening](/rulebook/control-flow-flatten) and [bogus control flow](/rulebook/bogus-control-flow) do that.

</Caveats>
</Guarantees>

## Output

The build report counts `conditions_strengthened`.

<PassPager pass="opaque" />
