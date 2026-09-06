# Refractor

A Dart kernel (`.dill`) obfuscation tool. Compiles a Dart entrypoint to kernel bytecode, applies configurable obfuscation passes, and outputs an executable, AOT snapshot, JIT snapshot, or kernel file.

> [!IMPORTANT]
> refractor is in early stages of development. Real impact at generated binary may differ.

## Features

- **Rename** — rewrites class, method, and field identifiers to short meaningless names
- **String encryption** — replaces string literals with XOR-encoded byte arrays and an injected runtime decoder
- **Symbol map** — writes a JSON mapping of obfuscated names back to originals for debugging
- **Build reports** — emits pass metrics and failures through structured build results
- **CI-friendly output** — writes GitHub Actions job summaries automatically when running in GitHub CI

## Installation

```bash
dart pub global activate --source git https://github.com/yardexx/refractor.git
```

## SDK Compatibility

Refractor is pinned to one Dart SDK line at a time because the vendored kernel
API and binary format are tied to a specific SDK snapshot.

This repository currently expects Dart `3.11.3`.

## Quick Start

```bash
# 1. Generate a config file
refractor init

# 2. Build with obfuscation
refractor build
```

This compiles `lib/main.dart`, applies the passes defined in `refractor.yaml`, and writes the output to `build/`.

Local runs print a plain-text build report. In GitHub Actions, Refractor also
appends a Markdown summary to `GITHUB_STEP_SUMMARY`.

## Commands

### `refractor build`

Compile, obfuscate, and build.

| Flag           | Description                                  | Default         |
|----------------|----------------------------------------------|-----------------|
| `-i, --input`  | Dart entrypoint file                         | `lib/main.dart` |
| `-t, --target` | Output format: `exe`, `aot`, `jit`, `kernel` | `exe`           |

The build output is always written to `build/out.<ext>` in the project root.

```bash
refractor build --target kernel
```

### `refractor inspect <path.dill>`

Print a tree representation of a compiled `.dill` file.

```bash
refractor inspect build/out.dill
refractor inspect --sdk build/out.dill   # include dart:* libraries
```

### `refractor init`

Generate a starter `refractor.yaml`.

```bash
refractor init
refractor init --output config/refractor.yaml
```

## Configuration

Create a `refractor.yaml` in your project root. The file is required — Refractor fails fast if it is missing, empty, or malformed.

Obfuscation scope is always the current project: libraries matching the `name` in `pubspec.yaml` and files under the working directory.

```yaml
refractor:
  # Path for the build artifacts JSON (includes the rename symbol map).
  artifact_json: build_artifacts.json
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
  verbose: false
  passes:
    rename: true

    string_encrypt:
      seed: 0x5A
      exclude_patterns:
        - "^https://"
```

Each pass value under `refractor.passes` can be `true` (enabled with defaults),
`false` (disabled), or a map with pass-specific options.

## Development

```bash
dart pub get
dart analyze
dart test
```

## License

MIT. See [LICENSE](LICENSE).
