---
title: Integer encryption
description: Hides integer literals behind a decoder that rebuilds them at runtime.
layout: docs
---

<PassFacts pass="ints" />

## What it does

Integer encryption does for numbers what
[string encryption](/rulebook/string-encryption) does for text. Each integer
literal is XOR-encoded with its own key and replaced by a call to an injected
decoder, so magic numbers like timeouts, limits and offsets no longer appear in
the binary.

## Example

`30000` is hidden behind the decoder; the `const` and the `1` (below `min_magnitude`) stay inline.

<PassCompare pass="ints">

```dart
const maxRetries = 3;

int backoff(int attempt) {
  final base = 30000;
  return base * (attempt + 1);
}
```

```dart
const maxRetries = 3;

int backoff(int attempt) {
  final base = refractorDecodeInt(
      0x6c21a9f3, 0x6c21dcc3);
  return base * (attempt + 1);
}
```

</PassCompare>

## What it targets

It encodes integer literals in your project's code whose absolute value is at
least `min_magnitude`. By default that leaves `-1`, `0` and `1` alone, so loop
counters and indexes don't all turn into function calls. Literals in a `const`
context or an annotation stay as they are, since kernel stores them as constants
rather than literals.

It follows `exclude` globs and `@Refractor.keep()`, like every pass. The entry point doesn't matter to it.

## Configuration

<Tabs defaultValue="minimal">
<TabItem label="Minimal" value="minimal">

```yaml
refractor:
  passes:
    int_encrypt: true
```

</TabItem>
<TabItem label="All options" value="all">

```yaml
refractor:
  passes:
    int_encrypt:
      enabled: true
      seed: 0x1F           # default
      min_magnitude: 2     # default: -1, 0, 1 stay inline
      exclude: []          # extra library globs
```

</TabItem>
</Tabs>

| Option | Type | Default | Meaning |
|---|---|---|---|
| `enabled` | bool | `true` | Turns the pass on or off. |
| `exclude` | glob list | `[]` | More libraries for this pass to skip, on top of the global `exclude`. |
| `seed` | int | `0x1F` | Seeds the random generator that picks each literal's 64-bit key. |
| `min_magnitude` | int | `2` | Literals whose absolute value is below this stay inline. Set it to `0` to encode every literal. |

## Guarantees & limitations

<Guarantees>
<Promises>

- Every value gets its own 64-bit key, so the same number doesn't encode the same way twice.
- The decoder is marked never-inline, so the compiler can't fold the XOR back into the original number.

</Promises>
<Caveats>

- It only stops casual reading. The keys are in the binary, so don't use it to hide key material.
- Each encoded literal becomes a function call, so keep `min_magnitude` sensible in hot code.

</Caveats>
</Guarantees>

## Output

The build report counts `ints_encrypted`.

<PassPager pass="ints" />
