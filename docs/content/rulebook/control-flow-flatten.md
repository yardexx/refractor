---
title: Control-flow flattening
description: Rewrites a straight-line body into a switch-dispatch state machine.
layout: docs
---

<PassFacts pass="flatten" />

## What it does

Rewrites a function's body into a **switch-dispatch state machine**. The `n`
statements become `n` switch cases laid out in a shuffled order; each case ends
by jumping to the next one via a labelled `continue`, so the program still runs
the statements in their original order — but the linear structure a decompiler
would show is gone.

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

Synchronous functions whose body is a block of two or more statements, where
each statement is one the state machine can carry: an **expression statement**, a
**`return`**, or a plain **local variable declaration** (not `late`, not
`const`). Local declarations are hoisted ahead of the switch so they stay in
scope across every case, and a `return` case exits the switch directly. It
**skips** async bodies and bodies with nested control flow (ifs, loops,
try/catch) — those are a follow-up.

## Configuration

<Tabs defaultValue="minimal">
<TabItem label="Minimal" value="minimal">

```
refractor:
  passes:
    control_flow_flatten: true
```

</TabItem>
<TabItem label="All options" value="all">

```
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
| `enabled` | bool | `true` | Turn the pass on/off. |
| `exclude` | glob list | `[]` | Extra libraries this pass leaves untouched. |
| `seed` | int | `0x0CFF` | Seeds the per-function case layout, for reproducible builds. |

## Scope & keep

Honors `exclude` globs and `@Refractor.keep()` annotations — a kept declaration
keeps its control flow intact. The entry point's name is irrelevant to it. See
[Policy](/architecture/policy).

## Guarantees & limitations

<Guarantees>
<Promises>

- **Execution order is preserved** by the continue links, regardless of the
  shuffled layout.
- **Declarations and returns are handled.** Locals are hoisted and re-assigned in
  place; a mid-body `return` still exits the function.

</Promises>
<Caveats>

- **Straight-line bodies only (for now).** Functions with nested `if`/loops/`try`
  or async bodies are left untouched rather than flattened unsoundly.

</Caveats>
</Guarantees>

## Output

- **Metrics:** `functions_flattened` (count).

<PassPager pass="flatten" />
