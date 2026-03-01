# Refractor

Refractor is a Dart kernel (`.dill`) obfuscation tool.

It compiles your Dart entrypoint to kernel, applies configurable obfuscation passes, and compiles the obfuscated kernel to your target output.

## What It Does

- Renames identifiers (classes, methods, fields) to harder-to-read names
- Encodes string literals via an injected runtime decoder
- Optionally inserts unreachable dead-code branches
- Writes a symbol map file for debugging/release workflows

## Current CLI Commands

- `refractor build` — compile -> obfuscate -> build
- `refractor inspect` — inspect a compiled `.dill` file
- `refractor init` — generate a `refractor.yaml` template

## Installation

Activate globally from Git:

```bash
dart pub global activate \
  --source git https://github.com/yardexx/refractor.git
```

## Quick Start

1. Create config:

```bash
refractor init
```

2. Build with obfuscation (default entrypoint: `lib/main.dart`):

```bash
refractor build --target exe --output build
```

This writes the output executable to `build/out`.

## Build Targets

Supported targets:

- `exe`
- `aot`
- `jit`
- `kernel`

Example (`kernel` target):

```bash
refractor build --target kernel --output build
```

This writes `build/out.dill`.

## Configuration (`refractor.yaml`)

Refractor looks for `refractor.yaml` in the current directory.

Example:

```yaml
refractor:
  symbol_map: symbol_map.json
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
  verbose: false

passes:
  rename:
    preserve_main: true

  string_encrypt:
    xor_key: 0x5A
    exclude_patterns:
      - "^https://"

  dead_code:
    enabled: false
    max_insertions_per_procedure: 2
```

Pass values can be:

- `true` (enabled with defaults)
- `false` (disabled)
- map/object with pass-specific options

## Command Reference

### `refractor build`

Options:

- `-i, --input` input Dart file or directory (default: `lib/main.dart`)
- `-o, --output` output directory (default: `build`)
- `-t, --target` output target: `exe|aot|jit|kernel`
- default target is `exe`

Example:

```bash
refractor build \
  --input lib/main.dart \
  --target exe \
  --output build
```

### `refractor inspect <path.dill>`

Prints a tree representation of a kernel file.

```bash
refractor inspect build/out.dill
```

Include SDK libraries:

```bash
refractor inspect --sdk build/out.dill
```

### `refractor init`

Creates a starter config file.

```bash
refractor init
```

Custom output path:

```bash
refractor init --output config/refractor.yaml
```

## Development

Run analysis and tests:

```bash
dart analyze
dart test
```

## License

MIT. See `NOTICE`.
