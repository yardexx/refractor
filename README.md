# Refractor

A Dart kernel (`.dill`) obfuscation tool. Compiles a Dart entrypoint to kernel bytecode, applies configurable obfuscation passes, and outputs an executable, AOT snapshot, JIT snapshot, or kernel file.

> [!IMPORTANT]
> refractor is in early stages of development. Real impact at generated binary may differ.

## Features

- **Rename** — rewrites class, method, and field identifiers to short meaningless names
- **String encryption** — replaces string literals with XOR-encoded byte arrays and an injected runtime decoder
- **Symbol map** — writes a JSON mapping of obfuscated names back to originals for debugging

## Installation

```bash
dart pub global activate --source git https://github.com/yardexx/refractor.git
```

## Quick Start

```bash
# 1. Generate a config file
refractor init

# 2. Build with obfuscation
refractor build
```

This compiles `lib/main.dart`, applies the passes defined in `refractor.yaml`, and writes the output to `build/`.

## Commands

### `refractor build`

Compile, obfuscate, and build.

| Flag           | Description                                  | Default         |
|----------------|----------------------------------------------|-----------------|
| `-i, --input`  | Dart entrypoint file                         | `lib/main.dart` |
| `-o, --output` | Output directory                             | `build`         |
| `-t, --target` | Output format: `exe`, `aot`, `jit`, `kernel` | `exe`           |

```bash
refractor build --target kernel --output build
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
```

Each pass value can be `true` (enabled with defaults), `false` (disabled), or a map with pass-specific options.

## Development

```bash
dart pub get
dart analyze
dart test
```

## License

MIT. See [LICENSE](LICENSE).
