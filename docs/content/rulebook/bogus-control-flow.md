---
title: Bogus control flow
description: Wraps a function body in an always-true branch whose else is a copy of the body.
layout: docs
---

<PassFacts pass="bogus" />

## What it does

Bogus control flow wraps a function's body in an `if` whose condition is always
true, and fills the `else` branch with a copy of the same body:

```dart
if (opaqueTrue) { realBody } else { clonedBody }
```

Only the real branch ever runs. The copy is genuine code rather than obvious
junk, so a reader can't dismiss it at a glance the way they can with
[dead code](/rulebook/dead-code).

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

## What it targets

It works on synchronous functions that have a non-nullable `int` parameter to
build the condition from, and whose body has at most `max_statements` top-level
statements. The body gets copied, so that limit is what keeps the size cost under
control. Async functions, functions without an `int` parameter and longer bodies
are skipped.

It follows `exclude` globs and `@Refractor.keep()`, like every pass.

## Configuration

<Tabs defaultValue="minimal">
<TabItem label="Minimal" value="minimal">

```yaml
refractor:
  passes:
    bogus_control_flow: true
```

</TabItem>
<TabItem label="All options" value="all">

```yaml
refractor:
  passes:
    bogus_control_flow:
      enabled: true
      seed: 0x3D            # default
      max_statements: 16    # default
      exclude: []           # extra library globs
```

</TabItem>
</Tabs>

| Option | Type | Default | Meaning |
|---|---|---|---|
| `enabled` | bool | `true` | Turns the pass on or off. |
| `exclude` | glob list | `[]` | More libraries for this pass to skip, on top of the global `exclude`. |
| `seed` | int | `0x3D` | Seeds which `int` parameter each condition uses, for reproducible builds. |
| `max_statements` | int | `16` | Functions with more top-level statements than this are left alone, since the body gets copied. |

## Guarantees & limitations

<Guarantees>
<Promises>

- Behaviour doesn't change. The condition, a masked square that can never be negative, is always true, so only the real branch runs.
- The copy is made with the kernel cloner, which rebinds every variable correctly, so it reads like real code.
- The condition reads a live parameter, so the optimizer can't prove it true and drop the branch.

</Promises>
<Caveats>

- Each wrapped body is copied, which doubles its size; `max_statements` keeps that bounded. Building the condition from a local, or wrapping only part of a body, isn't supported yet.

</Caveats>
</Guarantees>

## Output

The build report counts `bogus_branches_inserted`.

<PassPager pass="bogus" />
