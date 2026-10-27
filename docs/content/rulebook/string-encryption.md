---
title: String encryption
description: Hides string literals behind an injected runtime decoder.
layout: docs
---

# String encryption

## What it does

Replaces string literals in your code with a call to an injected runtime decoder,
so the plaintext no longer appears in the binary. At runtime the decoder
reconstructs the original string.

## What it targets

Non-empty, non-`const` string literals in **project** code. It **skips**:

- literals in a `const` context or inside annotations (they must stay const);
- empty strings;
- literals whose value matches any `exclude_patterns` regex (e.g. keep URLs readable).

## Configuration

```
refractor:
  passes:
    string_encrypt:
      enabled: true
      seed: 0x5A            # PRNG seed; each literal still gets its own key
      exclude:
        - "lib/src/logging/**"
      exclude_patterns:
        - "^https://"
```

| Option | Type | Default | Meaning |
|---|---|---|---|
| `enabled` | bool | `true` | Turn the pass on/off. |
| `exclude` | glob list | `[]` | Extra libraries this pass leaves untouched. |
| `seed` | int | `0x5A` | Seeds the PRNG that assigns a distinct key per literal — **not** a single fixed key. |
| `exclude_patterns` | regex list | `[]` | Literal values matching any pattern stay in plaintext. |

## Scope & keep

Honors `exclude` globs and `@Refractor.keep()` annotations. It does **not** honor
the entry point — keeping `main`'s name says nothing about the strings inside it.
See [Policy](/architecture/policy).

## Guarantees & limitations

- **Per-literal keys.** Each literal is XOR-encoded (bytes reversed) with its own
  key derived from the `seed` — identical strings don't produce identical bytes.
- **One decode helper per build**, injected as a top-level
  `@pragma('vm:never-inline')` function.
- **Not secrets protection.** This defeats `strings(1)` and casual inspection
  only. The key travels in the binary, so a determined reverse-engineer can
  recover the plaintext. Don't rely on it to hide credentials.
- `const` strings are left untouched by design.

## Output

- **Metrics:** `strings_encrypted` (count).
- **Artifact:** per-literal **records** (plaintext, encoded bytes, key, location)
  written into `build_artifacts.json`.

## Example

The `const` string has to stay a compile-time constant, so it is left alone; the other literal becomes a call to the injected decoder.

<PassCompare pass="strings">

```dart
const app = 'Acme Pay';

String banner() {
  final text = 'Welcome to Acme';
  return text;
}
```

```dart
const app = 'Acme Pay';

String banner() {
  final text = refractorDecode(
      [0x1d, 0x2f, …], 0x8c3f1a2b);
  return text;
}
```

</PassCompare>
