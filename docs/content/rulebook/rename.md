---
title: Rename
description: Renames classes, members, and variables to meaningless names.
layout: docs
---

<PassFacts pass="rename" />

## What it does

Rewrites the names of your classes, methods, fields, constructors, and local
variables/parameters to short meaningless identifiers, and updates every
reference so the program still runs. This is the pass that makes a decompiled
binary hard to read.

## Example

`Gateway` comes from a dependency, so it keeps its name, and so do its `pay` method and the `id` it returns; everything declared in your package is renamed.

<PassCompare pass="rename">

```dart
class Payments {
  final Gateway gateway;
  Payments(this.gateway);

  String charge(String token) {
    final receipt = gateway.pay(token);
    return receipt.id;
  }
}
```

```dart
class a {
  final Gateway b;
  a(this.b);

  String c(String d) {
    final e = b.pay(d);
    return e.id;
  }
}
```

</PassCompare>

## What it targets

Classes, members (methods, fields, constructors), and variables in **project**
code. It deliberately **skips**:

- compiler-synthesized mixin application classes (their generated names are load-bearing);
- instance members that override an **external** supertype (e.g. Flutter's `build`, or `==`/`hashCode`/`toString`) — renaming them would break the override contract with code you don't control;
- named parameters on dynamically-dispatched instance methods (can't be rewritten soundly once the receiver is `dynamic`);
- anything kept (see below) and the program entry point.

## Configuration

<Tabs defaultValue="minimal">
<TabItem label="Minimal" value="minimal">

```yaml
refractor:
  passes:
    rename: true
```

</TabItem>
<TabItem label="All options" value="all">

```yaml
refractor:
  passes:
    rename:
      enabled: true
      exclude: []     # extra library globs to skip
      # seed: 1337    # optional: fixes the names for
                      # reproducible builds
```

</TabItem>
</Tabs>

| Option | Type | Default | Meaning |
|---|---|---|---|
| `enabled` | bool | `true` | Turn the pass on/off. |
| `exclude` | glob list | `[]` | Extra libraries this pass leaves untouched. |
| `seed` | int | — | Optional seed for deterministic obfuscated names. |

## Scope & keep

Honors **all three** keep mechanisms: `exclude` globs, `@Refractor.keep()`
annotations, and the entry point (`main`'s name is preserved). See
[Policy](/architecture/policy).

## Guarantees & limitations

<Guarantees>
<Promises>

- **Overrides stay wired.** Members that form an override family across a class
  hierarchy are grouped (union-find) and given one shared new name.
- **Dynamic dispatch is reconciled**, and first-class tear-offs are preserved, by
  a safety-normalizer that reverts names it can't rewrite soundly.
- **Fails loud, never silently corrupts.** A validator asserts every planned
  rename was applied and that no two declarations collide on a name; a mismatch
  aborts the build with no output.

</Promises>
<Caveats>

- **Not covered.** Reflection/`dart:mirrors`-style lookups the pass can't see;
  named arguments at dynamic call sites; anything you've kept.

</Caveats>
</Guarantees>

## Output

- **Metrics:** `classes`, `members`, `variables` (counts).
- **Artifact:** a **symbol map** (obfuscated name → original) written into
  `build_artifacts.json`, so stack traces and logs can be de-obfuscated.

<PassPager pass="rename" />
