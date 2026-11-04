---
title: Bogus control flow
description: Wraps a function body in an always-true branch whose else is a copy of the body.
layout: docs
---

<PassFacts pass="bogus" />

## What it does

This pass wraps a function's body in an `if` whose condition is always true,
and fills the `else` branch with a copy of the same body. Only the real branch
ever runs. The copy is genuine code rather than obvious junk, so a reader can't
dismiss it at a glance the way they can with [dead code](/rulebook/dead-code).

<PassAnimation pass="bogus" />

## Example

The guard is always true, so only the first branch runs. The `else` is a clone of the real body rather than junk, so it can't be dismissed at a glance.

<PassCompare pass="bogus">

```dart
int fee(int n) {
  final base = n ~/ 40;
  return base + 25;
}
```

```dart
int fee(int n) {
  if ((n & 0xFFFF) * (n & 0xFFFF) >= 0) {
    final base = n ~/ 40;
    return base + 25;
  } else {
    final base = n ~/ 40;
    return base + 25;
  }
}
```

</PassCompare>

## What it changes

- Synchronous functions with a block body of up to `max_statements` top-level
  statements that have a non-nullable `int` parameter, positional or named, to
  build the condition from.

## What it leaves alone

- `async` functions, arrow (`=>`) bodies, and functions with only nullable
  `int` parameters, only `int` locals, or no `int` at all.
- Bodies longer than `max_statements`, and constructors with an initialiser
  list.
- Code kept with `exclude` or `@Refractor.keep()`.

## Configuration

```yaml
refractor:
  passes:
    bogus_control_flow:
      max_statements: 16   # longer bodies are left alone
```

| Option | Type | Default | Meaning |
|---|---|---|---|
| `seed` | int | `0x3D` | Seeds which `int` parameter each condition uses, for reproducible builds. |
| `max_statements` | int | `16` | Functions with more top-level statements than this are left alone, since the body gets copied. |

`enabled` and `exclude` work as on every pass; see
[Configuration](/guide/configuration#pass-options).

## Cost and strength

**Cost.** Each wrapped function's code roughly doubles in size. A function
called on its own ran at the same speed; one the compiler inlined into a tight
loop ran about twice as slow, since the guard is evaluated on every iteration.

**Strength.** The copy and the guard survive into a native build, except where
the compiler can see the guard's parameter is always the same constant: then it
folds the guard and drops the copy. The copy is an exact duplicate of the real
body, though, so putting the two branches side by side shows which is the decoy.

## Guarantees & limitations

<Guarantees>
<Promises>

- Behaviour doesn't change. The condition, a masked square that can never be negative, is always true, so only the real branch runs.
- The copy is made with the kernel cloner, which rebinds every variable correctly, so it reads like real code.

</Promises>
<Caveats>

- The copy is identical to the real body, so comparing the two branches gives it away.
- Each wrapped body is copied, which doubles its size; `max_statements` keeps that bounded. Building the condition from a local, or wrapping only part of a body, isn't supported yet.

</Caveats>
</Guarantees>

## Works with

- **Control-flow flattening.** Flattening skips bodies that contain an `if`, so
  list it first: it flattens the body, and this pass then wraps and copies the
  flattened version. Listed the other way round, the wrapped bodies aren't
  flattened. Passes run in the order they're listed.
- **Opaque predicates.** List them before this pass; listed after, they add a
  second copy of the same check to its guard, like `x >= 0 && x >= 0`.
- **Integer encryption.** Listed after this pass, it encrypts the guard's
  constants.

<PassPager pass="bogus" />
