# `refractor symbolicate`

**Status:** planned
**Owner:** maintainers
**Last reviewed:** 2026-03-23
**Applies to:** `v0.2.3` candidate scope
**Related:** [../../roadmap/v0.2-overview.md](../../roadmap/v0.2-overview.md), [04-crashlytics-symbol-format.md](04-crashlytics-symbol-format.md), [../README.md](../README.md)

## Goal

Deobfuscate Dart stack traces using the symbol map produced by `refractor
build`. The command should replace obfuscated identifiers with original names
without requiring engine-layer IO.

## Scope

Included:

- pure engine-layer symbolication logic
- CLI command for symbolication from file or stdin
- support for common Dart stack-trace identifier forms

Not included:

- native DWARF or Crashlytics console integration
- richer symbol browsing UI

## Acceptance Criteria

- obfuscated names in supported stack-trace lines are replaced correctly
- unknown names pass through unchanged
- stdin and file modes both work
- symbolication remains deterministic for a given symbol map

## Test Plan

- unit tests for identifier replacement cases
- CLI verification for file-based and stdin-based usage
- real stack-trace smoke test with a produced symbol map

## Open Questions

- how permissive should line parsing be for non-standard stack-trace formats?
- should the command support machine-readable output later, or remain plain text?

## Current Architecture

- `SymbolTable` stores `obfuscated → original` map, exports as JSON via `toJsonString()`
- `BuildCommand` writes symbol map to `config.symbolMapPath` via the
  CLI-layer `SymbolTableIo.writeToPath()` extension
- `RefractorCommandRunner` registers `BuildCommand`, `InitCommand`, `InspectCommand`
- Symbol map JSON format: `{ "_$0": "MyClass", "_$1": "myMethod" }`

---

## Files to Create

### `lib/src/engine/symbolicator.dart`

Pure engine-layer class (no `dart:io`). Parses Dart stack trace lines and replaces obfuscated identifiers.

```dart
class Symbolicator {
  const Symbolicator({required this.symbolMap});

  /// Map of obfuscated name → original name.
  final Map<String, String> symbolMap;

  /// Symbolicate a full stack trace string.
  String symbolicate(String stackTrace) {
    return stackTrace.split('\n').map(_symbolicateLine).join('\n');
  }

  String _symbolicateLine(String line) {
    // Dart stack trace format:
    //   #0      ClassName.methodName (package:foo/bar.dart:10:5)
    //   #1      topLevelFunction (package:foo/baz.dart:20:3)
    return line.replaceAllMapped(
      RegExp(r'(?<=#\d+\s+)(\S+)(?=\s+\()'),
      (match) => _replaceIdentifiers(match.group(1)!),
    );
  }

  String _replaceIdentifiers(String identifier) {
    // Split on dots, replace each part if in symbol map.
    // Preserves <anonymous closure> and other non-identifier parts.
    final parts = identifier.split('.');
    return parts.map((p) => symbolMap[p] ?? p).join('.');
  }
}
```

**Edge cases:**
- Dotted: `_$0._$1` → `MyClass.myMethod`
- Closures: `_$0._$1.<anonymous closure>` — replace `_$0` and `_$1`, leave `<anonymous closure>` alone
- Missing entries: pass through unchanged
- Empty/malformed lines: pass through unchanged
- Non-stacktrace lines (e.g. `Unhandled exception:`): pass through

### `lib/src/cli/commands/symbolicate_command.dart`

```dart
class SymbolicateCommand extends RefractorCommand {
  SymbolicateCommand({super.logger}) {
    argParser
      ..addOption(
        'symbol-map',
        abbr: 's',
        help: 'Path to the symbol map JSON file.',
        mandatory: true,
      )
      ..addOption(
        'trace',
        abbr: 't',
        help: 'Path to the stack trace file. '
            'Reads from stdin if not provided.',
      );
  }

  @override
  String get name => 'symbolicate';

  @override
  String get description =>
      'Replace obfuscated names in a stack trace with original names.';

  @override
  Future<int> run() async {
    // 1. Load symbol map JSON.
    // 2. Read stack trace (from file or stdin).
    // 3. Run Symbolicator.
    // 4. Output result.
  }
}
```

---

## Files to Modify

### `lib/src/cli/command_runner.dart`

Register the new command:

```dart
addCommand(SymbolicateCommand(logger: _logger));
```

---

## Tests

### Unit: `test/engine/symbolicator_test.dart`

- Replaces single identifier: `#0      _$2 (pkg:foo/bar.dart:10:5)` → `#0      handleRequest (...)`
- Replaces dotted identifier: `#0      _$0._$1 (...)` → `#0      MyClass.myMethod (...)`
- Handles anonymous closure suffix: `_$0._$1.<anonymous closure>` → `MyClass.myMethod.<anonymous closure>`
- Passes through unknown identifiers unchanged
- Passes through non-stacktrace lines unchanged
- Handles multi-line stack traces
- Empty symbol map passes everything through

---

## Verification Checklist

- [ ] `dart analyze` — zero warnings
- [ ] `dart test` — all tests pass
- [ ] `refractor symbolicate -s map.json -t trace.txt` works on a real stack trace
- [ ] stdin mode works: `cat trace.txt | refractor symbolicate -s map.json`
- [ ] Unknown identifiers pass through unchanged
