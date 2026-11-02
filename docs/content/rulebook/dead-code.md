---
title: Dead code
description: Adds junk code that never runs, behind a condition that is always false.
layout: docs
---

<PassFacts pass="dead" />

## What it does

This pass adds a block of junk to a function, behind a condition that is
always false, so anyone reading the code has to work out for themselves that
it never runs. The condition reads a live `int`, so it can't be settled just by
looking at it.

<PassAnimation pass="dead" />

## Example

The guard reads the `int` parameter `p`, and a masked square is never negative, so the block never runs.

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

## What it changes

- Functions with a block body that have a non-nullable positional `int`
  parameter (the block goes at the top), or an initialised `int` local that
  isn't `late` or `const` (the block goes right after it), including `async`
  functions.

## What it leaves alone

- Functions with only named or nullable `int` parameters, or no `int` at all.
- Arrow (`=>`) bodies and constructors with an initialiser list.
- Code kept with `exclude` or `@Refractor.keep()`.

## Configuration

```yaml
refractor:
  passes:
    dead_code: true
```

| Option | Type | Default | Meaning |
|---|---|---|---|
| `seed` | int | `0x0DEAD` | Seeds where each guard goes and the constants in the junk. |

`enabled` and `exclude` work as on every pass; see
[Configuration](/guide/configuration#pass-options).

## Cost and strength

**Cost.** None, in a native build: the block never runs, and as below, it
doesn't survive compilation.

**Strength.** In a native (AOT) build, none on its own. The junk is two
calculations whose results are thrown away, so the compiler removes them, and
then the empty `if` around them: a function with a dead-code block compiles to
exactly the same machine code as without one. With
[integer encryption](/rulebook/int-encryption) listed after this pass, the
guard survives, because the decoder calls inside it can't be removed, though
the arithmetic is still dropped. A fix that makes the junk itself survive is in
progress.

## Guarantees & limitations

<Guarantees>
<Promises>

- The block never runs. Its guard is always false, so behaviour doesn't change.

</Promises>
<Caveats>

- In a native build, the AOT compiler removes the block unless integer encryption runs after this pass.
- Every block has the same shape: a masked-square guard around two calculations. A careful reader can tell it isn't real logic. For a decoy that is an actual copy of your code, see [bogus control flow](/rulebook/bogus-control-flow).

</Caveats>
</Guarantees>

## Works with

- **Integer encryption.** Listed after this pass in `refractor.yaml`, it
  encrypts the guard's constants and keeps the guard alive in a native build,
  at about 2 nanoseconds per call of the function in a test. Passes run in the
  order they're listed.
- **Control-flow flattening.** Flattening skips bodies that contain an `if`,
  so listing dead code first stops those bodies from being flattened. Listed
  after flattening, dead code can't use a local that flattening has moved to
  the top of the function.
- **Opaque predicates.** List them before this pass; listed after, they
  strengthen its guard into a visible contradiction like `x < 0 && x >= 0`.

<PassPager pass="dead" />
