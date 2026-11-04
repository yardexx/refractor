---
title: Control-flow flattening
description: Turns a function body into a switch statement that runs it piece by piece.
layout: docs
---

<PassFacts pass="flatten" />

## What it does

A function body read top to bottom shows the order things happen in. This pass
rewrites the body as a small state machine: each statement becomes a case of a
`switch`, the cases are written out in a shuffled order, and each one ends by
jumping to the case that should run next. The statements still run in their
original order, but the straight line is gone.

<PassAnimation pass="flatten" />

## Example

The four statements become cases numbered in their original order and written out shuffled. `switch (0)` enters at case 0, each `continue` jumps to the next number, and `total` is hoisted so every case can see it.

<PassCompare pass="flatten">

```dart
int checkout(Cart cart) {
  final total = cart.sum();
  log(total);
  charge(total);
  return total;
}
```

```dart
int checkout(Cart cart) {
  int total;
  switch (0) {
    L2: case 2:
      charge(total);
      continue L3;
    L0: case 0:
      total = cart.sum();
      continue L1;
    L3: case 3:
      return total;
    L1: case 1:
      log(total);
      continue L2;
  }
}
```

</PassCompare>

## What it changes

- Bodies of two or more statements that run straight through: expression
  statements, `return`s and plain local variable declarations. That covers
  top-level functions, static and instance methods, getters, setters and
  constructor bodies.
- Locals are declared above the `switch` so every case can see them, and their
  declarations become assignments.

## What it leaves alone

- Bodies with an `if`, a loop or a `try`, and `async` bodies.
- Single-statement and arrow (`=>`) bodies.
- Bodies with `late` or `const` locals, or a local function declaration, and
  the bodies of local functions.
- Code kept with `exclude` or `@Refractor.keep()`.

## Configuration

```yaml
refractor:
  passes:
    control_flow_flatten: true
```

| Option | Type | Default | Meaning |
|---|---|---|---|
| `seed` | int | `0x0CFF` | Seeds the order of the cases in each function, for reproducible builds. |

`enabled` and `exclude` work as on every pass; see
[Configuration](/guide/configuration#pass-options).

## Cost and strength

**Cost.** None measurable: calls to a flattened function ran at the same speed
as before in a native executable, a JIT snapshot and a kernel file.

**Strength.** It only shows in kernel and JIT output. In a native (AOT) build
the compiler sees through the state machine and undoes it: an executable built
with flattening came out byte-identical to one built without it. And in the
kernel and JIT output where it does survive, the case numbers follow the
original order, so sorting the cases by number gives the sequence back.

## Guarantees & limitations

<Guarantees>
<Promises>

- Statements run in their original order. The `continue` jumps follow that order, whatever order the cases are written in.
- Local declarations and returns keep working: locals are hoisted and assigned in place, and a `return` in the middle of a body still exits the function.

</Promises>
<Caveats>

- In a native build, the AOT compiler undoes the flattening; it only protects kernel and JIT output.
- The case numbers follow the original order, so sorting the cases by number gives the sequence back.
- It only handles straight-line bodies for now. Functions with an `if`, a loop, a `try` or `async` are left as they are rather than flattened unsafely.

</Caveats>
</Guarantees>

## Works with

- **Dead code and bogus control flow.** Both add an `if` to the bodies they
  touch, and flattening skips bodies with an `if`. List flattening first in
  `refractor.yaml`: it flattens the bodies, and they then guard or wrap the
  flattened versions. Listed the other way round, most bodies aren't flattened.
  Passes run in the order they're listed.
- **The other passes** work in either order with flattening.

<PassPager pass="flatten" />
