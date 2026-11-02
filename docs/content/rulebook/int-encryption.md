---
title: Integer encryption
description: Hides integer literals behind a decoder that rebuilds them at runtime.
layout: docs
---

<PassFacts pass="ints" />

## What it does

Integer encryption does for numbers what
[string encryption](/rulebook/string-encryption) does for text. Magic numbers,
such as timeouts, limits, offsets and protocol constants, tell a reader a lot
about what code does. This pass XOR-encodes each integer literal with its own
key and replaces it with a call to a small decoder that Refractor adds to your
program.

<PassAnimation pass="ints" />

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

## What it changes

- Integer literals in your project's code whose absolute value is at least
  `min_magnitude` (2 by default).

## What it leaves alone

- `-1`, `0` and `1` by default, so loop counters and indexes don't all turn
  into function calls.
- Literals in a `const` context or an annotation, which have to stay constant.
- Code kept with `exclude` or `@Refractor.keep()`.

## Configuration

```yaml
refractor:
  passes:
    int_encrypt:
      min_magnitude: 2   # -1, 0 and 1 stay inline
```

| Option | Type | Default | Meaning |
|---|---|---|---|
| `seed` | int | `0x1F` | Seeds the random generator that picks each literal's 64-bit key. |
| `min_magnitude` | int | `2` | Literals whose absolute value is below this stay inline. Set it to `0` to encode every literal. |

`enabled` and `exclude` work as on every pass; see
[Configuration](/guide/configuration#pass-options).

## Cost and strength

**Cost.** Each encoded literal becomes a call to a decoder that is a single XOR.
In a native executable on an Apple-silicon Mac that came to about 0.3
nanoseconds per decode, measured over a hundred million loop iterations. That's
small, but a literal inside a tight loop pays it every time. The decoder and
the calls added about 50 bytes of code per literal.

**Strength.** The number no longer appears in the machine code: in a
disassembly of the built executable, the constants that were plain immediates
are gone, replaced by a load of two values and a call. That defeats reading
the code for magic numbers. It does not hold up against someone who finds the
decoder: the encoded value and its key are stored next to each other, and one
XOR gives the number back.

## Guarantees & limitations

<Guarantees>
<Promises>

- Every value gets its own 64-bit key, so the same number doesn't encode the same way twice.
- The decoder is marked never-inline, so the compiler can't fold the XOR back into the original number.

</Promises>
<Caveats>

- It isn't a way to protect secrets. The keys ship in the binary, right next to the values they decode, so don't use it to hide key material.
- Each encoded literal becomes a function call; raise `min_magnitude` or `exclude` the library for hot code.

</Caveats>
</Guarantees>

## Works with

- **Arithmetic mangling.** Mangling adds constants of its own (`a * b` becomes
  `a * (b + k) - a * k`). List integer encryption after it in
  `refractor.yaml` and those constants get encrypted too; listed before, they
  stay readable. Passes run in the order they're listed.
- **String encryption.** Integer encryption also encrypts the string decoder's
  own constants. Listed after string encryption, it goes further and encrypts
  every byte of every encoded string: that hides more, and made each string
  decode about a fifth slower in a test, against about a seventh when listed
  before.
- **Rename.** Without it, the decoder keeps its name, `refractorDecodeInt`, in
  the binary. With rename on, in either order, it's renamed.

<PassPager pass="ints" />
