---
title: Integer encryption
description: Hides integer literals behind an injected runtime decoder.
layout: docs
---

# Integer encryption

## What it does

Replaces integer literals in your code with a call to an injected runtime
decoder, so the original magic numbers don't appear in the binary. It's the
integer analogue of [String encryption](/rulebook/string-encryption): each value
is XOR-encoded with its own key, and a `@pragma('vm:never-inline')` helper
recovers it at runtime.

## What it targets

Non-`const` integer literals in **project** code whose absolute value is at least
`min_magnitude`. It **skips**:

- literals in a `const` context or inside annotations (they must stay const —
  these are `ConstantExpression`s in kernel, not plain literals);
- small, ubiquitous values below `min_magnitude` (by default `-1`, `0`, `1`), so
  the pass doesn't turn every loop counter and array index into a call;
- anything kept.

## Configuration

```
refractor:
  passes:
    int_encrypt:
      enabled: true
      seed: 0x1F          # PRNG seed; each literal still gets its own key
      min_magnitude: 2    # leave |value| < 2 (i.e. -1, 0, 1) inline
```

| Option | Type | Default | Meaning |
|---|---|---|---|
| `enabled` | bool | `true` | Turn the pass on/off. |
| `exclude` | glob list | `[]` | Extra libraries this pass leaves untouched. |
| `seed` | int | `0x1F` | Seeds the PRNG that assigns a distinct 64-bit key per literal. |
| `min_magnitude` | int | `2` | Literals with `|value|` below this stay inline. Set to `0` for maximum coverage. |

## Scope & keep

Honors `exclude` globs and `@Refractor.keep()` annotations. The entry point's
name is irrelevant to it. See [Policy](/architecture/policy).

## Guarantees & limitations

- **Per-literal keys.** Each value is XOR-encoded with its own 64-bit key, so
  identical numbers don't encode identically.
- **Not foldable.** The decoder is `@pragma('vm:never-inline')`, so the AOT
  compiler can't inline it and fold the XOR back into the original constant.
- **Not secrets protection.** Like string encryption, this defeats casual
  inspection only — the key is in the binary. Don't use it to hide key material.
- **Performance tradeoff.** Each encoded literal becomes a function call; keep
  `min_magnitude` sensible on hot paths.

## Output

- **Metrics:** `ints_encrypted` (count).

## Example

```dart
// before
int timeoutMs = 30000;

// after (illustrative)
int timeoutMs = refractorDecodeInt(0x6c21a9f3, 0x6c219c03);
```
