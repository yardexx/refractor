---
title: Getting Started
description: Install Refractor and obfuscate your first Dart build.
layout: docs
---

# Refractor

Refractor is a Dart kernel (`.dill`) obfuscation tool. It compiles a Dart
entrypoint to kernel bytecode, applies configurable obfuscation passes, and
emits an executable, AOT snapshot, JIT snapshot, or kernel file.

<Info>
Refractor is in early development. Real impact on the generated binary may vary.
</Info>

## What it does

Refractor runs a configurable set of **obfuscation passes** over your compiled
program — see the [Rulebook](/rulebook) for exactly what each one does:

- **Naming & data** — rename identifiers, and encrypt string and integer
  literals behind injected runtime decoders.
- **Expressions** — mangle integer arithmetic into equivalent, uglier forms.
- **Control flow** — opaque predicates, control-flow flattening, dead code,
  bogus branches, and call indirection.

Alongside the transforms:

- **Symbol map** — every build writes a versioned `symbol_map.json`, and
  [`refractor symbolicate`](/recipes/symbolication) turns an obfuscated stack
  trace back into original names.
- **Build reports** — pass metrics and failures through structured build output,
  including a GitHub Actions job summary in CI.

## SDK compatibility

Refractor is pinned to one Dart SDK line at a time, because the vendored kernel
API and binary format are tied to a specific SDK snapshot. This release expects
Dart **3.11.3**.

## Install

```
dart pub global activate --source git https://github.com/yardexx/refractor.git
```

## Quick start

```
# 1. Generate a config file
refractor init

# 2. Build with obfuscation
refractor build
```

This compiles `lib/main.dart`, applies the passes defined in `refractor.yaml`,
and writes the output to `build/out.exe`.

Local runs print a plain-text build report. In GitHub Actions, Refractor also
appends a Markdown summary to `GITHUB_STEP_SUMMARY`.

## Next steps

- [Commands](/guide/commands) — `build`, `symbolicate`, `inspect`, `init`, and the global `--verbose`.
- [Configuration](/guide/configuration) — the `refractor.yaml` reference.
- [Architecture](/architecture) — how Refractor is built, end to end.

## Project & license

Refractor is open source at
[github.com/yardexx/refractor](https://github.com/yardexx/refractor); issues and
contributions are welcome. See the repository's `LICENSE` file for licensing
terms.
