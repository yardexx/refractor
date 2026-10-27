---
title: Opaque predicates
description: Entangles branch conditions with always-true predicates the optimizer can't fold.
layout: docs
---

<PassFacts pass="opaque" />

## What it does

Strengthens the `if` conditions already in your code by folding in an **opaque
predicate** — an extra sub-expression whose value is known to be constant to
you, but not to a static analyzer. The predicate is wired to a **live variable**
in scope, so the compiler can't fold it away, and a reader can't tell at a
glance that the branch is decided. Control flow is unchanged: the predicate is
always true, so the original condition still decides the branch.

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

`if` statements in **project** code, outside any `const` context. At each site
the pass finds the nearest in-scope `int` (a parameter or a block-local
declaration) and keys the predicate off it. Sites with no live `int` in scope
fall back to a constant-only predicate. It **skips** conditions in const
contexts and anything kept.

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
| `enabled` | bool | `true` | Turn the pass on/off. |
| `exclude` | glob list | `[]` | Extra libraries this pass leaves untouched. |
| `seed` | int | `0x05A1` | Seeds per-site template and variable selection, for reproducible builds. |

## Scope & keep

Honors `exclude` globs and `@Refractor.keep()` annotations — a kept declaration
keeps its control flow intact. It does **not** touch the entry point's name, so
it does not honor that keep source. See [Policy](/architecture/policy).

## Guarantees & limitations

<Guarantees>
<Promises>

- **Behaviour-preserving.** The predicate is always true, so the original
  condition alone decides the branch.
- **Data-dependent, not foldable.** Keying on a live `int` (e.g. a masked square,
  which is never negative) stops the optimizer from proving the predicate
  constant and dropping it.
- **Per-site variation.** The `seed` drives which template and which in-scope
  variable each site uses, so the inserted predicates don't all look identical.

</Promises>
<Caveats>

- **Not a loop or data-flow obfuscator.** It hardens existing branch conditions;
  it doesn't add or reorder control flow (see
  [Control-flow flattening](/rulebook/control-flow-flatten) and
  [Bogus control flow](/rulebook/bogus-control-flow) for that).

</Caveats>
</Guarantees>

## Output

- **Metrics:** `conditions_strengthened` (count).

<PassPager pass="opaque" />
