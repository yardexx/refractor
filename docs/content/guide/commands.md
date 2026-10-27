---
title: Commands
description: The Refractor CLI — build, symbolicate, inspect, init.
layout: docs
---

# Commands

All commands accept a global `-v, --verbose` flag for detailed logging (the
underlying `dart compile` commands and per-pass progress).

```
refractor --verbose build
```

## `refractor build`

Compile, obfuscate, and build.

| Flag | Description | Default |
|---|---|---|
| `-i, --input` | Dart entrypoint file | `lib/main.dart` |
| `-t, --target` | Output format: `exe`, `aot`, `jit`, `kernel` | `exe` |

The build output is always written to `build/` in the project root: `build/out`
for `exe`, and `build/out.aot`, `build/out.jit`, or `build/out.dill` for the
other targets.
When the [rename](/rulebook/rename) pass runs, the build also writes a versioned
**symbol map** to `build/symbol_map.json` (path configurable via
`refractor.symbol_map`) — the input [`symbolicate`](/guide/commands#refractor-symbolicate-trace-file)
uses to de-obfuscate stack traces. See
[Debugging with the symbol map](/recipes/symbolication).

```
refractor build --target kernel
```

## `refractor symbolicate [trace-file]`

Reverse an obfuscated stack trace back to original identifiers, using the symbol
map from a build.

| Flag | Description | Default |
|---|---|---|
| `-m, --symbol-map` | Symbol map JSON; relative paths resolve under the build directory | `symbol_map.json` |

The trace is read from `trace-file` if given, otherwise from **stdin**; the
symbolicated trace is written to stdout.

```
refractor symbolicate crash.txt
flutter logs | refractor symbolicate
refractor symbolicate crash.txt --symbol-map build/symbol_map.json
```

## `refractor inspect <path.dill>`

Print a tree representation of a compiled `.dill` file.

```
refractor inspect build/out.dill
refractor inspect --sdk build/out.dill   # include dart:* libraries
```

## `refractor init`

Generate a starter `refractor.yaml`.

| Flag | Description | Default |
|---|---|---|
| `-o, --output` | Output path for the config file | `refractor.yaml` |

```
refractor init
refractor init --output config/refractor.yaml
```
