---
title: Dead code
description: Adds junk code that never runs, behind a guard the compiler can't prove false.
layout: docs
---

<PassFacts pass="dead" />

## What it does

Dead code adds a block of plausible-looking junk to a function, behind a
condition that is always false. The condition reads a live `int`, so the
optimizer can't prove it false and drop the block, and anyone reading the code
has to work out for themselves that it never runs.

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

It needs a function with a block body and an `int` to build the guard from.
That is either an `int` parameter, in which case the block goes at the top of the
body, or an `int` local that is definitely assigned and not `late` or `const`, in
which case the block goes right after its declaration. Functions with neither are
skipped.

It follows `exclude` globs and `@Refractor.keep()`, like every pass.

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
| `enabled` | bool | `true` | Turns the pass on or off. |
| `exclude` | glob list | `[]` | More libraries for this pass to skip, on top of the global `exclude`. |
| `seed` | int | `0x0DEAD` | Seeds where each guard goes and the constants in the junk. |

## Guarantees & limitations

<Guarantees>
<Promises>

- The block never runs. Its guard is always false, so behaviour doesn't change.
- The guard reads a live variable, so the optimizer can't prove it false and remove the block.

</Promises>
<Caveats>

- The junk is arithmetic on the guard's variable. It looks like work at a glance, but a careful reader can tell it isn't real logic. For a decoy that is an actual copy of your code, see [bogus control flow](/rulebook/bogus-control-flow).

</Caveats>
</Guarantees>

## Output

The build report counts `blocks_inserted`.

<PassPager pass="dead" />
