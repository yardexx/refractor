# Refractor — Dart Kernel Obfuscator

## Project Overview

Refractor is a CLI tool that takes compiled `.dill` files (Dart kernel binary),
applies a pipeline of obfuscation passes, and writes obfuscated `.dill` files.
It supports standalone `.dill` → `.dill` obfuscation, full build pipelines
(compile → obfuscate → compile), and Flutter integration via a frontend server proxy.

## Project Status

All phases complete:
- **Phase 1:** Core obfuscation engine (3 passes)
- **Phase 2:** Build integration (config, Flutter safety, CLI, frontend server proxy)
- **Phase 3:** Orchestrator rearchitecture (PassRunner + RefractorEngine + abstract interfaces)
- **Phase 4:** Architecture rethink (injectable logging, naming cleanup, directory restructure)
- **Phase 5:** Test stabilization and internal technical debt (using test fixtures, auto-generated models, compiler sealing)

87 tests, all passing.

---

## Architecture

Three-layer design with strict dependency direction: CLI → Infra → Engine.

### Engine (`lib/src/engine/`) — Pure, no dart:io
- `pass.dart` — Abstract `Pass` interface
- `pass_options.dart` — `PassOptions` (immutable config for passes)
- `pass_context.dart` — `PassContext` (mutable shared state: SymbolTable + NameGenerator + PassOptions)
- `pass_runner.dart` — Runs passes on a `Component`, returns `(Component, SymbolTable)`
- `engine.dart` — `RefractorEngine` + `BuildRequest` + `BuildResult`. Full compile → obfuscate → compile pipeline. Takes abstract `Compiler` and `KernelIO` interfaces.
- `compiler/compiler.dart` — `Target` enum + abstract `Compiler` interface (sealed hierarchy with `DartCompiler`, `FlutterCompiler`)
- `kernel/kernel_io.dart` — Abstract `KernelIO` interface (load/write Component)
- `name_generator.dart` — Sequential `_$N` name generator
- `symbol_table.dart` — Obfuscated → original name mapping
- `passes/rename_pass.dart` — Two-phase identifier renaming
- `passes/string_encrypt_pass.dart` — XOR string encryption
- `passes/dead_code_pass.dart` — Dead branch insertion
- `config/` — Configuration system (see below)

### Infra (`lib/src/infra/`) — File system, processes
- `dart_compiler.dart` — `DartCompiler` (implements `Compiler`)
- `file_kernel_io.dart` — `FileKernelIO` (implements `KernelIO`)
- `config_loader.dart` — `loadRefractorConfig()`, `resolveConfig()`
- `flutter_detector.dart` — `isFlutterProject()`
- `frontend_server_proxy.dart` — Flutter frontend server wrapper
- `process_runner.dart` — Sync subprocess runner + `ProcessException`
- `symbol_table_io.dart` — `SymbolTable.writeToFile()` extension

### CLI (`lib/src/cli/`) — User-facing commands
- `command_runner.dart` — `RefractorCommandRunner`
- `commands/build_command.dart` — Full pipeline: `refractor build <target>`
- `commands/obfuscate_command.dart` — Direct: `refractor obfuscate <input.dill>`
- `commands/init_command.dart` — Scaffold `refractor.yaml`
- `logger_adapter.dart` — `initLog(Logger)` installs mason_logger as `Log` backend

### Barrel file
`lib/refractor.dart` — Public API for programmatic use (no dart:io dependency, zero `hide`/`show`/`as`).

---

## Logging

The logger is now injectable instead of a static field. This improves testability and decouples the engine from specific logging implementations.

CLI commands initialize the logger (via `mason_logger`) and pass it down through the `CompilerBridge` or `RefractorEngine`.

---

## CLI Interface

### `refractor build [options] <target>`

Full compile → obfuscate → compile pipeline.

**Flags:** `--input`/`-i`, `--output`/`-o`, `--verbose`/`-v`
**Targets:** `exe`, `aot`, `jit`, `kernel`

### `refractor obfuscate [options] <input.dill>`

Direct `.dill` → `.dill` obfuscation.

**Flags:** `--output`/`-o`, `--verbose`/`-v`

### `refractor init`

Scaffolds a `refractor.yaml` template. Use `--flutter` for Flutter-specific template.

All obfuscation settings are configured via `refractor.yaml`. CLI flags are minimal — operational only.

---

## Configuration System

Config file: `refractor.yaml` (auto-discovered in project root).

### Key classes
- `RefractorConfig` (`lib/src/config/model/refractor_config.dart`) — Top-level config
- `RefractorSettings` — Global settings (symbol_map, exclude, verbose, include/excludePackages)
- Sealed `PassConfig` hierarchy: `RenamePassConfig`, `StringEncryptPassConfig`, `DeadCodePassConfig`
- Generated classes (`.g.dart`) created via `build_runner` and `json_serializable` for data models.
- Engine pass classes in `lib/src/engine/passes/` have no suffix — no name collision

### Config methods
- `RefractorConfig.fromYaml(String)` — Parse YAML
- `toOptions()` — Convert to `PassOptions`
- `buildPasses()` — Create engine `Pass` instances
- `validate()` — Return list of errors
- `applyFlutterSafety(isFlutter:)` — Merge Flutter-protected names/annotations
- `passesFromNames(List<String>)` — Static factory for pass list

### Config resolution chain
```dart
resolveConfig({bool? isFlutter}) // load YAML → apply Flutter safety
```

### Example `refractor.yaml`
```yaml
passes:
  rename:
    preserve_main: true
    exclude_names: [dispose, build]
    exclude_patterns: ["^on[A-Z]"]
    exclude_annotations: [JsonKey]
  string_encrypt:
    xor_key: 90
  dead_code:
    max_insertions_per_procedure: 2

refractor:
  symbol_map: build/symbol_map.json
  verbose: false
```

### Include directive
```yaml
include: base_config.yaml  # relative path or package: URI
```
Included configs are deep-merged (user config wins).

---

## Key Implementation Details

### `package:kernel` dependency
Uses a git dependency pinned to the Dart SDK version.
The kernel binary format version must match the host SDK.

### RenamePass — Two-phase + canonical name unbind
1. **_NameCollector** (RecursiveVisitor): Builds identity-based rename maps
2. **_NameApplier** (Transformer): Applies renames to declarations AND call sites
3. **Canonical name unbind**: `lib.reference.canonicalName?.unbindAll()` for renamed libraries

System names never renamed: `toString`, `hashCode`, `noSuchMethod`, `runtimeType`, `==`, `_enumToString`

### StringEncryptPass
- XOR key configurable (default 0x5A)
- Injects `_obfDecode$` helper into first user library
- Skips const contexts and annotations

### DeadCodePass
- Inserts `if (false) { ... }` branches (zero runtime cost)
- Default: 1 insertion per procedure

### Flutter safety
- Auto-detects Flutter projects via `pubspec.yaml`
- Uses a default-protect annotation system with `@Refract.keep` as the sole exclusion mechanism.
- Merges ~30 protected names, 7 protected annotations, `^on[A-Z]` pattern

---

## Testing

87 tests total. Tests have been refactored to use memory-based fixture files (`MemoryFileSystem`) instead of hardcoded strings for better maintainability:
- `test/log_test.dart` — 4 tests (Log static class)
- `test/name_generator_test.dart` — 4 tests
- `test/symbol_table_test.dart` — 8 tests
- `test/pass_context_test.dart` — 5 tests (shouldObfuscateLibrary)
- `test/pass_runner_test.dart` — 4 tests (ordering, returns, logging)
- `test/rename_pass_test.dart` — 11 unit tests
- `test/obfuscator_test.dart` — 1 integration test (compile → obfuscate → run)
- `test/build_config_test.dart` — 33 tests (config schema, parsing, validation, includes, passesFromNames)
- `test/flutter_safety_test.dart` — 12 tests (detection + safety)
- `test/build_pipeline_test.dart` — 5 integration tests (RefractorEngine pipeline)

---

## Rules

- Run `dart test` after changes. Keep tests green.
- Run `dart analyze` frequently. Zero errors.
- Use `package:` imports everywhere, never relative `../lib/` imports.
- Don't modify passes unless fixing a bug discovered during integration.
- The `package:kernel` dependency is fragile — don't change unless SDK version changes.

---

## Tech Stack

- **Language:** Dart (SDK ^3.10.0)
- **Core dependencies:** `kernel` (git), `args`, `yaml`, `path`, `json_annotation`, `mason_logger`, `cli_completion`, `checked_yaml`
- **Dev dependencies:** `test`, `very_good_analysis`, `lints`, `build_runner`, `json_serializable`

---

## Useful `package:kernel` API Reference

| Task | API |
|---|---|
| Load .dill | `loadComponentFromBinary(path)` |
| Write .dill | `BinaryPrinter(sink).writeComponentFile(component)` |
| Walk AST (read-only) | `extends RecursiveVisitor` |
| Walk + mutate AST | `extends Transformer` |
| All libraries | `component.libraries` |
| All classes in library | `library.classes` |
| All procedures in class | `class_.procedures` |
| All fields in class | `class_.fields` |
| Top-level procedures | `library.procedures` |
| Create a Name | `Name('myName')` or `Name('_private', library)` |
| Check if SDK | `library.importUri.scheme == 'dart'` |
| Check annotations | `node.annotations` (List of `Expression`) |
