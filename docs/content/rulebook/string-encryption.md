---
title: String encryption
description: Hides string literals behind a decoder that rebuilds them at runtime.
layout: docs
---

<PassFacts pass="strings" />

## What it does

String encryption replaces each string literal with a call to a small decoder
that Refractor adds to your program. The text is stored in encoded form, so it
no longer shows up in the binary, and the decoder rebuilds it when the code
runs.

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

## What it targets

It encodes non-empty string literals in your project's code. It leaves alone
strings in a `const` context or an annotation, which have to stay constant, empty
strings, and any literal whose text matches one of your `exclude_patterns`, for
example to keep URLs readable.

It follows `exclude` globs and `@Refractor.keep()`, but not the entry point:
keeping `main`'s name says nothing about the strings inside it.

## Configuration

<Tabs defaultValue="minimal">
<TabItem label="Minimal" value="minimal">

```yaml
refractor:
  passes:
    string_encrypt: true
```

</TabItem>
<TabItem label="All options" value="all">

```yaml
refractor:
  passes:
    string_encrypt:
      enabled: true
      seed: 0x5A              # default
      exclude: []             # extra library globs
      exclude_patterns: []    # literal regexes kept
                              # in plaintext
```

</TabItem>
</Tabs>

| Option | Type | Default | Meaning |
|---|---|---|---|
| `enabled` | bool | `true` | Turns the pass on or off. |
| `exclude` | glob list | `[]` | More libraries for this pass to skip, on top of the global `exclude`. |
| `seed` | int | `0x5A` | Seeds the random generator that picks each literal's key. Every literal still gets a different key. |
| `exclude_patterns` | regex list | `[]` | Literals whose text matches any of these stay in plain text. |

## Guarantees & limitations

<Guarantees>
<Promises>

- Every literal gets its own key, derived from the `seed`, so two identical strings don't produce the same bytes.
- Refractor adds one decoder per build, marked `@pragma('vm:never-inline')` so the compiler keeps it as a separate function.

</Promises>
<Caveats>

- It isn't a way to protect secrets. It defeats `strings` and casual browsing, but the keys ship inside the binary, so someone determined can recover the text. Don't use it to hide credentials.
- `const` strings stay readable, by design.

</Caveats>
</Guarantees>

## Output

The build report counts `strings_encrypted`. A record for each literal (its
text, encoded bytes, key and location) goes into `build_artifacts.json`, so keep
that file out of anything you ship.

<PassPager pass="strings" />
