---
title: String encryption
description: Hides string literals behind a decoder that rebuilds them at runtime.
layout: docs
---

<PassFacts pass="strings" />

## What it does

The text of your strings is often the quickest way into a binary: run `strings`
on it and URLs, error messages and feature names fall out. This pass stores each
literal encoded, with its own key, and swaps the literal for a call to a small
decoder that Refractor adds to your program.

<PassAnimation pass="strings" />

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

## What it changes

- Non-empty string literals in your project's code.
- The literal parts of interpolated strings: in `'Fee: $fee'`, the `'Fee: '`
  part is encoded and `$fee` is left as it is.

## What it leaves alone

- Strings in a `const` context or an annotation, which have to stay constant.
- Empty strings.
- Literals whose text matches one of your `exclude_patterns`.
- Code kept with `exclude` or `@Refractor.keep()` (see [Policy](/architecture/policy)).

## Configuration

```yaml
refractor:
  passes:
    string_encrypt:
      exclude_patterns:
        - "^https://"   # keep URLs readable
```

| Option | Type | Default | Meaning |
|---|---|---|---|
| `seed` | int | `0x5A` | Seeds the random generator that picks each literal's key. Every literal still gets a different key. |
| `exclude_patterns` | regex list | `[]` | Literals whose text matches any of these stay in plain text. |

`enabled` and `exclude` work as on every pass; see
[Configuration](/guide/configuration#pass-options).

## Cost and strength

**Cost.** Nothing is cached: every time an encrypted literal is evaluated, the
decoder rebuilds the string. In a native executable on an Apple-silicon Mac,
that came to about 0.3 µs per evaluation for a 27-character string, against
practically nothing for the plain literal. The decoder added 16 KB to a small
test app. A literal evaluated once is free in practice; one inside a hot loop
is not, so move it out of the loop or `exclude` that library.

**Strength.** `strings` on the built executable no longer finds the text, and
neither does a search through the binary for it. That stops casual browsing and
simple tooling. It does not stop someone who finds the decoder: the keys ship
in the same binary, and running the decoder gives the text back.

## Guarantees & limitations

<Guarantees>
<Promises>

- Every literal gets its own key, derived from the `seed`, so two identical strings don't produce the same bytes.
- The decoder is a single function, marked `@pragma('vm:never-inline')` so the compiler keeps it in one place instead of copying it into every call site.

</Promises>
<Caveats>

- It isn't a way to protect secrets. The keys ship inside the binary, so don't use it to hide credentials or API keys.
- `const` strings stay readable, by design.

</Caveats>
</Guarantees>

## Works with

- **Rename.** Without it, the decoder keeps its name, `refractorDecode`, in the
  binary, which points straight at every encrypted string. Turn rename on as
  well.
- **Integer encryption.** It also encrypts the decoder's own constants, which
  makes the decoder harder to read and each decode slower. Listed after string
  encryption in `refractor.yaml`, it goes further and encrypts every byte of
  every encoded string as well: in a test that made each decode about a fifth
  slower, against about a seventh when listed before.
- **Call indirection.** Listed after string encryption in `refractor.yaml`, it
  routes the decoder calls through its forwarder too. That hides the decoder
  from the call graph, at the cost of a slower decode. Passes run in the order
  they're listed.

## Output

A record for each literal (its text, encoded bytes, key and location) goes into
`build_artifacts.json`. That file undoes the encryption, so keep it out of
anything you ship.

<PassPager pass="strings" />
