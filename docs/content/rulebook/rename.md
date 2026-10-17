---
title: Rename
description: Renames classes, members, and variables to meaningless names.
layout: docs
---

# Rename

## What it does

Rewrites the names of your classes, methods, fields, constructors, and local
variables/parameters to short meaningless identifiers, and updates every
reference so the program still runs. This is the pass that makes a decompiled
binary hard to read.

## What it targets

Classes, members (methods, fields, constructors), and variables in **project**
code. It deliberately **skips**:

- compiler-synthesized mixin application classes (their generated names are load-bearing);
- instance members that override an **external** supertype (e.g. Flutter's `build`, or `==`/`hashCode`/`toString`) — renaming them would break the override contract with code you don't control;
- named parameters on dynamically-dispatched instance methods (can't be rewritten soundly once the receiver is `dynamic`);
- anything kept (see below) and the program entry point.

## Configuration

```
refractor:
  passes:
    rename:
      enabled: true
      exclude:
        - "lib/src/public_api/**"
      seed: 1337      # optional; fixes the name allocation for reproducible builds
```

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

- **Overrides stay wired.** Members that form an override family across a class
  hierarchy are grouped (union-find) and given one shared new name.
- **Dynamic dispatch is reconciled**, and first-class tear-offs are preserved, by
  a safety-normalizer that reverts names it can't rewrite soundly.
- **Fails loud, never silently corrupts.** A validator asserts every planned
  rename was applied and that no two declarations collide on a name; a mismatch
  aborts the build with no output.
- **Not covered:** reflection/`dart:mirrors`-style lookups the pass can't see;
  named arguments at dynamic call sites; anything you've kept.

## Output

- **Metrics:** `classes`, `members`, `variables` (counts).
- **Artifact:** a **symbol map** (obfuscated name → original) written into
  `build_artifacts.json`, so stack traces and logs can be de-obfuscated.

## Example

```dart
// before
class PaymentProcessor {
  String chargeCard(String token) => _gateway.charge(token);
}

// after (names illustrative)
class a {
  String b(String c) => _d.charge(c);
}
```
