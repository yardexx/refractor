---
title: Arithmetic mangling
description: Rewrites integer + and * into equivalent, harder-to-read expressions.
layout: docs
---

# Arithmetic mangling

## What it does

Rewrites integer addition and multiplication into algebraically equivalent but
less obvious expressions. `a + b` becomes `(a ^ b) + ((a & b) << 1)`; `a * b`
becomes `a * (b + k) - a * k` for a constant `k`. The result is the same number;
the expression a reader (or a decompiler) sees is not.

## What it targets

Integer `+` and `*` operations in **project** code — matched structurally: the
operator is `+` or `*`, both operands are `int`/`num`, and the result is `int`.
Nested arithmetic is rewritten bottom-up, so compound expressions are mangled
throughout. It **skips** floating-point math, operations in const contexts, and
anything kept.

## Configuration

```
refractor:
  passes:
    arithmetic_mangle:
      enabled: true
      seed: 0x0A17    # fixes the identities and constants chosen per site
```

| Option | Type | Default | Meaning |
|---|---|---|---|
| `enabled` | bool | `true` | Turn the pass on/off. |
| `exclude` | glob list | `[]` | Extra libraries this pass leaves untouched. |
| `seed` | int | `0x0A17` | Seeds the identity/constant choices, for reproducible builds. |

## Scope & keep

Honors `exclude` globs and `@Refractor.keep()` annotations. The entry point's
name is irrelevant to it. See [Policy](/architecture/policy).

## Guarantees & limitations

- **Behaviour-preserving.** The rewrites are algebraic identities over Dart's
  64-bit integers — the computed value is unchanged.
- **Side effects fire exactly once.** Operands with side effects are bound to
  temporaries before being reused, so `f() + g()` still calls each once.
- **Integers only.** Doubles and mixed `num` results are left alone to avoid any
  rounding or precision change.

## Output

- **Metrics:** `operations_mangled` (count).

## Example

```dart
// before
int total = price + tax;

// after (illustrative)
int total = (price ^ tax) + ((price & tax) << 1);
```
