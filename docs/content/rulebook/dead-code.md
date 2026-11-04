---
title: Dead code
description: Adds junk code that never runs, behind a condition that is always false.
layout: docs
---

<PassFacts pass="dead" />

## What it does

This pass adds a block of plausible-looking work to a function, behind a
condition that is always false, so anyone reading the code has to work out for
themselves that it never runs. The condition reads a live `int`, so it can't be
settled just by looking at it, and the block computes a value and uses it, so
the compiler can't throw it away either.

<PassAnimation pass="dead" />

## Example

The guard reads the `int` parameter `p`, and a masked square is never negative, so it is never below `-812` and the block never runs. The block returns what it computes, so the compiler has to keep it.

<PassCompare pass="dead">

```dart
int scale(int p) {
  final factor = p * 2;
  return factor + 1;
}
```

```dart
int scale(int p) {
  if ((p & 0x3FF) * (p & 0x3FF) < -812) {
    int t = p * 7;
    t = t ^ 4093;
    return t;
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
| `seed` | int | `0x0DEAD` | Seeds where each block goes, its guard's mask and bound, and the calculation inside it. |

`enabled` and `exclude` work as on every pass; see
[Configuration](/guide/configuration#pass-options).

## Cost and strength

**Cost.** The block never runs, but its guard is checked on every call: about
half a nanosecond per call in a native executable on an Apple-silicon Mac,
measured on a tiny function. Each block adds roughly 60 to 120 bytes of
machine code.

**Strength.** The block survives into a native build: every function in a
53-function test kept its block in the compiled machine code, guard and body.
Each block computes a value in one to four steps and then uses it, by
assigning it back to the variable, returning it or throwing it, so the
compiler can't prove it unused. The guard's mask and bound change from block
to block, though every guard is a masked square compared with a negative
number, so a reader who knows the pattern can still spot it.

## Guarantees & limitations

<Guarantees>
<Promises>

- The block never runs. Its guard is always false, so behaviour doesn't change.

</Promises>
<Caveats>

- Every guard follows the same pattern, a masked square compared with a negative number, so once a reader knows it they can spot the blocks.
- The calculation inside is arithmetic on the guard's variable. It looks like work at a glance, but a careful reader can tell it isn't real logic. For a decoy that is an actual copy of your code, see [bogus control flow](/rulebook/bogus-control-flow).

</Caveats>
</Guarantees>

## Works with

- **Integer encryption.** Listed after this pass in `refractor.yaml`, it
  encrypts the guard's and the block's constants too, at the cost of a decoder
  call for each. Passes run in the order they're listed.
- **Control-flow flattening.** Flattening skips bodies that contain an `if`,
  so listing dead code first stops those bodies from being flattened. Listed
  after flattening, dead code can't use a local that flattening has moved to
  the top of the function.
- **Opaque predicates.** List them before this pass; listed after, they
  strengthen its guard into a visible contradiction, such as a value checked to
  be both negative and not negative.

<PassPager pass="dead" />
