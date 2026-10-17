---
title: Debugging with the symbol map
description: Turn obfuscated stack traces back into their original names.
layout: docs
---

# Debugging with the symbol map

Renaming makes production stack traces unreadable — the frames carry the
obfuscated identifiers, not your originals. Refractor closes the loop: every
build emits a **symbol map**, and the `symbolicate` command uses it to rewrite a
captured trace back to the original names.

## 1. Keep the symbol map from each release

When the [rename](/rulebook/rename) pass runs, `refractor build` writes a stable,
versioned **`symbol_map.json`** next to your build output (default
`build/symbol_map.json`; change the path with `refractor.symbol_map`). It maps
obfuscated names back to originals, with library-scoped keys for private members
so colliding short names resolve correctly.

```
refractor:
  symbol_map: symbol_map.json   # relative paths resolve under build/
  passes:
    rename: true
```

Archive this file for every release you ship, keyed by version — it's the key to
reading a crash report after the fact.

<Info>
Treat `symbol_map.json` like a debug-symbols file: **archive it, don't ship it.**
Publishing it next to the binary hands an attacker the de-obfuscation map.
</Info>

## 2. Symbolicate a captured trace

Feed an obfuscated trace to [`symbolicate`](/guide/commands#refractor-symbolicate-trace-file)
with the matching map — from a file or over a pipe:

```
refractor symbolicate crash.txt --symbol-map build/symbol_map.json
flutter logs | refractor symbolicate
```

It rewrites the **symbol** in each stack frame and prints the result to stdout:

```
# before
#0      a.b (package:app/checkout.dart:42:7)
#1      c (package:app/main.dart:10:3)

# after
#0      PaymentProcessor.chargeCard (package:app/checkout.dart:42:7)
#1      runCheckout (package:app/main.dart:10:3)
```

## What it does and doesn't touch

- **Only the identifier is rewritten.** The file location in each frame is left
  exactly as-is, so a path that happens to match an obfuscated name is never
  corrupted.
- **Unmapped tokens and non-frame lines pass through** verbatim — exception
  headers, blank lines, and interleaved output are untouched.
- **Private members are disambiguated by frame.** A short private name that
  collides across libraries is resolved using the frame's own library URI, so
  the right original comes back.

<Info>
This is **identifier-level** symbolication — it reverses the renames Refractor
performed. It is not address-level AOT symbolication of non-symbolic frames;
that's Dart's own `--save-debugging-info` + `symbolize` domain, and the two
compose: run Dart's step first to get symbolic frames, then `refractor
symbolicate` to recover the original names.
</Info>

## The map format

`symbol_map.json` is schema-versioned so tooling can depend on it:

```
{
  "version": 1,
  "kind": "refractor-symbol-map",
  "symbols": {
    "a": "PaymentProcessor",
    "package:app/checkout.dart::_b": "_gateway"
  }
}
```

Public classes and members are keyed by their bare obfuscated name; private
members are keyed `<library-uri>::<name>`.
