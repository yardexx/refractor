---
title: Control-flow flattening
description: Turns a function body into a switch statement that runs it piece by piece.
layout: docs
---

<PassFacts pass="flatten" />

## What it does

Control-flow flattening rewrites a function's body as a small state machine.
Each statement becomes a case of a `switch`, the cases are shuffled, and each one
ends by jumping to the case that should run next. The statements still run in
their original order, but the straight line a decompiler would show is gone.

## Example

The four statements become shuffled cases entered at case 2. The `continue` labels still run them in their original order, and `total` is hoisted so every case can see it.

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
  switch (2) {
    L0: case 0:
      log(total);
      continue L3;
    L1: case 1:
      return total;
    L2: case 2:
      total = cart.sum();
      continue L0;
    L3: case 3:
      charge(total);
      continue L1;
  }
}
```

</PassCompare>

## What it targets

It flattens synchronous functions whose body has at least two statements, all of
a kind the state machine can carry: expression statements, `return`s, and plain
local variable declarations (not `late` or `const`). Locals are declared before
the `switch` so every case can see them, and a `return` leaves the function
straight from its case. Async bodies, and bodies with an `if`, a loop or a `try`
inside, are skipped for now.

It follows `exclude` globs and `@Refractor.keep()`, like every pass.

## Configuration

<Tabs defaultValue="minimal">
<TabItem label="Minimal" value="minimal">

```yaml
refractor:
  passes:
    control_flow_flatten: true
```

</TabItem>
<TabItem label="All options" value="all">

```yaml
refractor:
  passes:
    control_flow_flatten:
      enabled: true
      seed: 0x0CFF    # default
      exclude: []     # extra library globs
```

</TabItem>
</Tabs>

| Option | Type | Default | Meaning |
|---|---|---|---|
| `enabled` | bool | `true` | Turns the pass on or off. |
| `exclude` | glob list | `[]` | More libraries for this pass to skip, on top of the global `exclude`. |
| `seed` | int | `0x0CFF` | Seeds the order of the cases in each function, for reproducible builds. |

## Guarantees & limitations

<Guarantees>
<Promises>

- Statements run in their original order. The `continue` jumps follow that order, whatever order the cases are written in.
- Local declarations and returns keep working: locals are hoisted and assigned in place, and a `return` in the middle of a body still exits the function.

</Promises>
<Caveats>

- It only handles straight-line bodies for now. Functions with an `if`, a loop, a `try` or `async` are left as they are rather than flattened unsafely.

</Caveats>
</Guarantees>

## Output

The build report counts `functions_flattened`.

<PassPager pass="flatten" />
