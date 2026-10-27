---
title: Bogus control flow
description: Wraps a body in an always-true branch whose else-branch is a real-looking clone.
layout: docs
---

<PassFacts pass="bogus" />

## What it does

Wraps a function's body in an **always-true opaque branch** whose else-branch is
a faithful **clone** of the real body:

```
if (opaqueTrue) { realBody } else { clonedBody }
```

The guard always selects the real branch, so behaviour is unchanged — but the
else-branch is plausible, real-looking code rather than obvious junk, so an
attacker can't dismiss it at a glance the way they can with
[Dead code](/rulebook/dead-code).

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

Synchronous functions with a non-nullable `int` **parameter** (to key the
always-true guard) and a body of at most `max_statements` top-level statements.
The body is cloned into the bogus branch, so that limit bounds the code-size
cost. It **skips** async functions, functions with no int parameter, oversized
bodies, and anything kept.

## Configuration

<Tabs defaultValue="minimal">
<TabItem label="Minimal" value="minimal">

```
refractor:
  passes:
    bogus_control_flow: true
```

</TabItem>
<TabItem label="All options" value="all">

```
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
| `enabled` | bool | `true` | Turn the pass on/off. |
| `exclude` | glob list | `[]` | Extra libraries this pass leaves untouched. |
| `seed` | int | `0x3D` | Seeds the guard-parameter choice, for reproducible builds. |
| `max_statements` | int | `16` | Functions whose body exceeds this are left alone (cloning doubles the body). |

## Scope & keep

Honors `exclude` globs and `@Refractor.keep()` annotations — a kept declaration
keeps its control flow intact. The entry point's name is irrelevant to it. See
[Policy](/architecture/policy).

## Guarantees & limitations

<Guarantees>
<Promises>

- **Behaviour-preserving.** The masked-square guard (`(v & 0xFFFF)² >= 0`) is
  always true, so only the real branch ever runs.
- **Real-looking decoy.** The clone is produced with the kernel cloner (variables
  correctly rebound), so it reads as genuine code, not junk.
- **Not foldable.** The guard reads a live parameter, so the optimizer can't
  prove it and drop the branch.

</Promises>
<Caveats>

- **Code-size cost.** Cloning doubles the wrapped body; `max_statements` keeps it
  bounded. Keying on in-scope locals and partial-body branches are follow-ups.

</Caveats>
</Guarantees>

## Output

- **Metrics:** `bogus_branches_inserted` (count).

<PassPager pass="bogus" />
