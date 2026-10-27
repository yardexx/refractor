---
title: Quickstart
description: Install and run Refractor in your Dart project.
layout: docs
---

This page takes a fresh Dart console app from install to an obfuscated
executable. Every command below was run against the sample project that
`dart create` generates, so you can follow along exactly or swap in your own
project.

## Prerequisites

You need the Dart SDK at exactly **3.11.3**. Refractor ships a vendored copy of
the kernel library that is tied to one SDK snapshot, so other versions are not
supported (see [SDK compatibility](/guide#sdk-compatibility)). Check yours with:

```sh
dart --version
```

## 1. Install the CLI

```sh
dart pub global activate --source git https://github.com/yardexx/refractor.git
```

This puts a `refractor` executable in pub's global bin directory. If your shell
can't find it afterwards, add `~/.pub-cache/bin` to your `PATH` — pub prints the
exact line to add when it isn't there yet.

## 2. Create a project

Skip this if you already have one. Otherwise, generate the standard console
sample:

```sh
dart create -t console hello_refractor
cd hello_refractor
```

Refractor only obfuscates code that belongs to your package — the libraries
named after the `name` in `pubspec.yaml`, plus files under the project root.
Dependencies and the SDK are left alone.

## 3. Generate a config

```sh
refractor init
```

This writes a starter `refractor.yaml` to the project root. Refractor refuses to
build without one. The starter file turns on two passes, **rename** and
**string encryption**, with the other options commented out:

```yaml
refractor:
  passes:
    rename:
      enabled: true
    string_encrypt:
      enabled: true
```

You can enable more passes later; the [Configuration](/guide/configuration)
reference lists them all.

## 4. Build

`refractor build` compiles `lib/main.dart` by default. Console apps keep their
entrypoint in `bin/`, so point `--input` at it:

```sh
refractor build --input bin/hello_refractor.dart
```

Refractor compiles the app to kernel, runs the enabled passes, and compiles the
result to a native executable. It prints a report of what each pass changed:

```text
✅ Build report: 2 pass(es) succeeded.

✅ rename:
Classes renamed: 0
Members renamed: 2
Variables renamed: 6
…
Build complete: /path/to/hello_refractor/build/out
```

If any pass fails, the build exits non-zero and writes no output, so you never
end up with a half-obfuscated binary.

## 5. Check the result

The build leaves three files in `build/`:

| File | What it is |
|---|---|
| `out` | The obfuscated executable. |
| `symbol_map.json` | Maps obfuscated names back to the originals. |
| `build_artifacts.json` | Per-pass records from the build. |

Run the executable and it behaves exactly like the original:

```sh
./build/out
```

```text
Hello world: 42!
```

The renames are recorded in `symbol_map.json`. The sample's `calculate`
function, for example, now has a one-letter name (the exact names vary):

```json
{
  "version": 1,
  "kind": "refractor-symbol-map",
  "symbols": {
    "t": "calculate",
    …
  }
}
```

<Info>

Keep `symbol_map.json` out of anything you ship. It is the key that undoes the
renaming. Archive it privately with each release so you can
[symbolicate](/recipes/symbolication) crash reports later.

</Info>

## Next steps

- [Configuration](/guide/configuration) — enable more passes and tune them.
- [Commands](/guide/commands) — build AOT or JIT snapshots with `--target`,
  inspect `.dill` files, and symbolicate stack traces.
- [Rulebook](/rulebook) — what each pass does to your code.
- [Continuous integration](/recipes/ci) — run Refractor in CI.
