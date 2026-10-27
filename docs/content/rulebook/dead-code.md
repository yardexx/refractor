---
title: Dead code
description: Inserts never-executed, opaquely-guarded junk a reader must rule out.
layout: docs
---

<PassFacts pass="dead" />

## What it does

Inserts a block of plausible-looking junk into function bodies, behind an
**always-false** opaque guard, so it never runs. The guard — a masked square
that can never be negative — reads a live `int`, so the optimizer can't prove it
false and drop the block. A reader has to analyze the junk to discover it's
unreachable.

## Example

The guard reads the `int` parameter `p`, so the compiler can't fold it away, and a masked square is never negative, so the block never runs.

<PassCompare pass="dead">

```dart
int scale(int p) {
  final factor = p * 2;
  return factor + 1;
}
```

```dart
int scale(int p) {
  if ((p & 0xFFFF) * (p & 0xFFFF) < 0) {
    p + 40503;
    p * 12789;
  }
  final factor = p * 2;
  return factor + 1;
}
```

</PassCompare>

## What it targets

Functions with a block body and a live `int` to key the guard from — either an
`int` **parameter** (the block goes at the top of the body) or a
definitely-assigned, non-`late`, non-`const` `int` **local** (the block goes
just after that local's declaration). Functions with neither are **skipped**, as
is anything kept.

## Configuration

<Tabs defaultValue="minimal">
<TabItem label="Minimal" value="minimal">

```yaml
refractor:
  passes:
    dead_code: true
```

</TabItem>
<TabItem label="All options" value="all">

```yaml
refractor:
  passes:
    dead_code:
      enabled: true
      seed: 0x0DEAD   # default
      exclude: []     # extra library globs
```

</TabItem>
</Tabs>

| Option | Type | Default | Meaning |
|---|---|---|---|
| `enabled` | bool | `true` | Turn the pass on/off. |
| `exclude` | glob list | `[]` | Extra libraries this pass leaves untouched. |
| `seed` | int | `0x0DEAD` | Seeds the per-function guard site and junk constants. |

## Scope & keep

Honors `exclude` globs and `@Refractor.keep()` annotations — a kept declaration
is left untouched. The entry point's name is irrelevant to it. See
[Policy](/architecture/policy).

## Guarantees & limitations

<Guarantees>
<Promises>

- **Never runs.** The guard is always false, so the inserted block has no effect
  on behaviour.
- **Not foldable.** Because the guard reads a live variable, the optimizer can't
  prove it false and eliminate the block at compile time.

</Promises>
<Caveats>

- **Plausible, not real.** The junk is arithmetic over the live variable — it
  looks like work but is dead. For a branch whose *else* is real-looking cloned
  code, see [Bogus control flow](/rulebook/bogus-control-flow).

</Caveats>
</Guarantees>

## Output

- **Metrics:** `blocks_inserted` (count).

<PassPager pass="dead" />
