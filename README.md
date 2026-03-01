# Refractor — Dart Kernel Obfuscation Tool

A production-ready Dart kernel obfuscation tool that applies multiple passes to `.dill` files, making reverse-engineered code difficult to analyze. Designed for developers shipping compiled Dart/Flutter apps who need to protect proprietary logic.

**Status:** Fully functional. Phase 1 (core engine) and Phase 2 (build integration) complete. 56 tests, zero analyzer errors.

## Features

- **Identifier Renaming** — Classes, methods, fields, parameters renamed to meaningless short names (`_$0`, `_$1`, ...) while preserving correctness
- **String Encryption** — String literals XOR-encoded with runtime decoding, keeping plaintext out of binaries
- **Dead Code Insertion** — Unreachable `if(false)` branches confuse static analysis without runtime overhead
- **Build Integration** — Seamless compile → obfuscate → final-compile pipeline in one command
- **Configuration as Code** — `refractor.yaml` config (inspired by `analysis_options.yaml`) with preset inheritance
- **Flutter Safety** — Auto-protects widget lifecycle, serialization annotations, and generated files
- **Symbol Maps** — JSON mapping of original → obfuscated names for production debugging
- **Multi-Pass Pipeline** — Chain obfuscation passes with independent configuration
- **Zero Runtime Cost** — Dead code eliminated by VM optimizer; obfuscation happens at compile time

## Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dev_dependencies:
  refractor: ^0.1.0
```

Or use directly from git:

```yaml
dev_dependencies:
  refractor:
    git:
      url: https://github.com/yardexx/refractor.git
      ref: main
```

### Initialize Configuration

```bash
dart run refractor:refractor init --flutter
```

Creates `refractor.yaml` in your project:

```yaml
include: package:refractor/presets/flutter_defaults.yaml

refractor:
  symbol_map: build/refractor_map.json

passes:
  rename:
    exclude_names: []
  string_encrypt: true
  dead_code: false
```

### Build with Obfuscation

```bash
# Compile a pure Dart app
dart run refractor:refractor build exe -o build/app

# Build a Flutter app (auto-applies Flutter safety)
flutter pub get
dart run refractor:refractor build exe -o build/app_release

# Compile to kernel only (intermediate format)
dart run refractor:refractor build kernel -o build/app.dill
```

## Configuration

### Schema Overview

The `refractor.yaml` file follows `analysis_options.yaml` conventions for familiarity:

```yaml
# Inherit framework-specific defaults
include: package:refractor/presets/flutter_defaults.yaml

# Global tool settings
refractor:
  symbol_map: build/refractor_map.json
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"

# Pass configuration (map-style toggles + config)
passes:
  rename:
    preserve_main: true
    exclude_names:
      - myImportantMethod
    exclude_patterns:
      - "^on[A-Z]"      # Event handlers
    exclude_annotations:
      - JsonKey
      - HiveField

  string_encrypt:
    xor_key: 0x5A       # Encoding key

  dead_code:
    max_insertions_per_procedure: 2
```

### Configuration Options

#### Global (`refractor:` section)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `symbol_map` | string | — | Path to write original→obfuscated name mapping (JSON) |
| `exclude` | list | `[]` | Glob patterns for files to skip (e.g., generated code) |
| `package_filter` | string | — | Only obfuscate URIs containing this string |
| `verbose` | bool | `false` | Enable verbose logging during obfuscation |

#### Rename Pass

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `preserve_main` | bool | `true` | Keep `main()` entrypoint unobfuscated |
| `exclude_names` | list | `[]` | Exact names never to rename |
| `exclude_patterns` | list | `[]` | Regex patterns; matching names skipped |
| `exclude_annotations` | list | `[]` | Annotation class names; annotated members skipped |

#### String Encrypt Pass

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `xor_key` | int | `0x5A` | XOR key for encoding strings |

#### Dead Code Pass

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `max_insertions_per_procedure` | int | `2` | Max fake branches per function |

### Presets

**Built-in presets** (include with `include: package:refractor/presets/...`):

- `recommended.yaml` — Safe defaults for pure Dart projects
- `flutter_defaults.yaml` — Flutter-aware protections + safe exclusions

Example (Flutter project):

```yaml
include: package:refractor/presets/flutter_defaults.yaml

refractor:
  symbol_map: build/map.json

passes:
  rename: true        # Use defaults from preset
  string_encrypt: true
  dead_code: false
```

### CLI Flags (Override Config)

All options can be overridden via flags:

```bash
dart run refractor:refractor build exe \
  --config my_config.yaml \
  --passes rename,string_encrypt \
  --preserve-main false \
  --exclude-names foo,bar \
  --map-output build/symbols.json \
  -o build/my_app
```

## CLI Usage

### `refractor build [options] <target>`

Full compile → obfuscate → final-compile pipeline.

**Targets:** `exe`, `aot`, `jit`, `kernel`

**Options:**
```
-i, --input                Entry point (default: lib/main.dart)
-o, --output               Output path (default: build/<name>.<ext>)
--passes                   Comma-separated pass names
--config                   Path to refractor.yaml (auto-searches)
--map-output               Symbol map JSON output
--preserve-main            Keep main() name (default: true)
--package-filter           Only obfuscate matching URIs
--exclude-names            Names to skip (comma-separated)
--keep-intermediates       Don't delete temp .dill files
-v, --verbose              Verbose logging
```

**Example:**
```bash
dart run refractor:refractor build exe \
  -i lib/main.dart \
  -o build/myapp \
  --map-output build/symbols.json \
  --verbose
```

### `refractor obfuscate [options] <input.dill>`

Low-level `.dill` → `.dill` obfuscation (no compilation step).

**Options:**
```
-o, --output               Output .dill path
--passes                   Comma-separated pass names
--map-output               Symbol map JSON
--preserve-main            Keep main() (default: true)
--package-filter           Only obfuscate matching URIs
--verbose                  Verbose logging
```

**Example:**
```bash
dart compile kernel lib/main.dart -o app.dill
dart run refractor:refractor obfuscate \
  -o app.obfuscated.dill \
  --map-output symbols.json \
  app.dill
dart run app.obfuscated.dill
```

### `refractor init [options]`

Generate a `refractor.yaml` template.

**Options:**
```
-o, --output               Output file (default: refractor.yaml)
--flutter                  Include Flutter preset
```

## Examples

### Pure Dart CLI App

```yaml
# refractor.yaml
passes:
  rename: true
  string_encrypt: true
  dead_code: false

refractor:
  symbol_map: build/symbols.json
```

```bash
dart run refractor:refractor build exe -o build/my_cli_app
```

### Flutter App (Recommended)

```yaml
# refractor.yaml
include: package:refractor/presets/flutter_defaults.yaml

refractor:
  symbol_map: build/symbols.json

passes:
  rename: true
  string_encrypt: true
  dead_code: false
```

```bash
flutter pub get
dart run refractor:refractor build exe -o build/app_release
```

### Selective Obfuscation

Only obfuscate your package, not dependencies:

```yaml
# refractor.yaml
passes:
  rename: true

refractor:
  package_filter: my_app
  symbol_map: build/symbols.json
```

### Exclude Generated Code

```yaml
# refractor.yaml
refractor:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "**/*.gr.dart"
    - "lib/generated_plugin_registrant.dart"

passes:
  rename: true
  string_encrypt: true
```

### Event Handlers + Serialization

```yaml
# refractor.yaml
passes:
  rename:
    exclude_patterns:
      - "^on[A-Z]"       # onPressed, onTap, etc.
    exclude_annotations:
      - JsonKey
      - JsonSerializable
      - HiveField

  string_encrypt: true
```

## How It Works

### Architecture

```
lib/src/engine/          ← Pure obfuscation engine (no dart:io)
  ├── obfuscator.dart    ← Pass orchestrator
  ├── passes/            ← Rename, StringEncrypt, DeadCode
  ├── config/            ← Pure config parsing + merging
  └── util/              ← NameGenerator, SymbolTable

lib/src/io/              ← File I/O & processes
  ├── config_loader.dart ← Load YAML + resolve includes
  ├── dill_io.dart       ← Load/save .dill files
  ├── pipeline.dart      ← Compile → obfuscate → compile
  └── ...

lib/src/cli/             ← Command-line interface
  ├── command_runner.dart
  └── commands/          ← build, obfuscate, init

lib/presets/             ← Shipped configuration presets
  ├── recommended.yaml
  └── flutter_defaults.yaml

bin/refractor.dart       ← CLI entrypoint
```

### The Obfuscation Pipeline

1. **Compile** → `dart compile kernel lib/main.dart -o app.dill`
2. **Load** → Parse binary kernel format
3. **Passes**:
   - **RenamePass** — Two-phase (collect → apply) identifier renaming
   - **StringEncryptPass** — XOR-encode strings, inject decoder helper
   - **DeadCodePass** — Insert unreachable branches
4. **Symbol Map** — Record original → obfuscated mappings
5. **Write** → Binary kernel format back to disk
6. **Compile** → `dart compile exe app.obfuscated.dill -o app`

Each pass runs independently and can be toggled or configured.

## Security Considerations

**What it protects:**
- ✅ Hides class/method/field names from reverse engineering
- ✅ Encrypts string literals (configs, keys, URLs, messages)
- ✅ Adds noise to confuse static analysis
- ✅ Prevents symbol table reconstruction

**What it doesn't protect:**
- ❌ Algorithm logic (can still be reverse-engineered from bytecode)
- ❌ Cryptographic keys embedded in code (use environment variables/secure storage)
- ❌ Network traffic (use encryption like TLS/DTLS)
- ❌ Against determined, skilled attackers with access to Dart VM source code

**Recommended use:**
- Protect proprietary business logic from casual inspection
- Comply with app store policies (some require obfuscation)
- Combined with other security measures (encryption, code signing, etc.)

For cryptographic keys and secrets, use platform-specific secure storage (Keychain on iOS, Keystore on Android, OS credential managers on desktop).

## Testing

Run the test suite:

```bash
dart test
```

Test files:
- `test/build_config_test.dart` — Config parsing, merging, includes (30 tests)
- `test/rename_pass_test.dart` — Identifier renaming (8 tests)
- `test/flutter_safety_test.dart` — Flutter detection & protections (10 tests)
- `test/obfuscator_test.dart` — Integration test (1 test)
- `test/build_pipeline_test.dart` — Full compile → obfuscate → compile (5 tests)

**Total:** 56 tests, all passing.

## Development

### Building from Source

```bash
git clone https://github.com/yardexx/refractor.git
cd refractor
dart pub get
dart test
dart run bin/refractor.dart --help
```

### Code Quality

```bash
dart analyze
dart format lib test bin
```

### Key Files

- **Engine config:** `lib/src/engine/config/build_config.dart` (pure YAML parsing, auto-detects legacy vs new schema)
- **Include resolution:** `lib/src/io/config_loader.dart` (resolves `package:` URIs, deep-merges configs)
- **Rename pass:** `lib/src/engine/passes/rename_pass.dart` (three-phase: collect → apply → unbind)
- **Flutter safety:** `lib/src/engine/config/flutter_safety.dart` (pure; detector in IO layer)

## Known Limitations

- Obfuscation is best-effort; determined attackers can still decompile bytecode
- Renaming relies on `CanonicalName` stability; kernel format changes may require updates
- String encryption has minimal overhead; XOR is not cryptographically secure (not intended to be)
- Obfuscated code can still be instrumented/debugged (symbols are at runtime)

## Roadmap

- [ ] Advanced passes: control flow flattening, string splitting, metadata obfuscation
- [ ] Deobfuscation tools for crash reporting
- [ ] Framework-specific presets (GetX, Riverpod, etc.)
- [ ] Web UI for config builder
- [ ] Integration plugins for build_runner, Mason

## Contributing

Contributions welcome! Please:

1. Run `dart test` and `dart analyze` before submitting
2. Follow Dart style guide (`dart format`)
3. Add tests for new features
4. Update docs/comments

## License

MIT License — See LICENSE file.

## Support

- **Issues:** [GitHub Issues](https://github.com/yardexx/refractor/issues)
- **Discussions:** [GitHub Discussions](https://github.com/yardexx/refractor/discussions)
- **Docs:** See [CLAUDE.md](CLAUDE.md) for implementation details

---

**Made with ❤️ for the Dart ecosystem.**