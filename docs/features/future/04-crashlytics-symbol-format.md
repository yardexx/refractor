# Crashlytics Symbol Format

**Status:** research
**Owner:** maintainers
**Last reviewed:** 2026-03-23
**Applies to:** `v0.2.3` candidate scope
**Related:** [../../roadmap/v0.2-overview.md](../../roadmap/v0.2-overview.md), [03-symbolicate.md](03-symbolicate.md), [05-artifact-handling.md](05-artifact-handling.md), [../README.md](../README.md)

## Goal

Export symbol data in a format that works with the most practical crash-report
deobfuscation workflow available to Refractor users.

## Scope

Included:

- determine the viable integration path
- define a symbol format option if needed
- keep engine-layer formatting logic separate from CLI IO

Not included:

- generating native DWARF debug info
- claiming full Crashlytics console integration without proof

## Acceptance Criteria

- the chosen format and workflow are explicitly documented
- output generation is covered by tests
- the resulting file is usable by the intended downstream tool

## Test Plan

- unit tests for format generation
- manual verification against the intended consumer tool
- regression coverage for existing symbol-map output

## Open Questions

- should this target `flutter symbolize` compatibility only, or a broader
  Crashlytics-facing workflow?
- should Refractor emit one symbol format or multiple formats by default?

## Current Architecture

- `SymbolTable` stores `obfuscated → original` map
- `toJsonString()` exports as `{ "_$0": "MyClass", "_$1": "myMethod" }` — our custom format
- disk writing now lives in the CLI layer via `SymbolTableIo.writeToPath()`
- `BuildCommand` writes the symbol map after build without reintroducing
  `dart:io` into the engine

---

## Research Needed

This feature requires research before implementation. The exact integration path is not yet determined.

### Key Questions

1. **What format does Crashlytics expect?**
   - Firebase Crashlytics for Flutter/Dart uses `--split-debug-info` which produces DWARF debug symbols.
   - Dart's `--obfuscate` flag produces a separate symbol file read by `flutter symbolize`.
   - The two formats serve different purposes and are not interchangeable.

2. **Dart `--obfuscate` symbol file format:**
   When using `dart compile exe --obfuscate --save-debugging-info=<path>`, the output JSON:
   ```json
   [
     {"original": "MyClass", "obfuscated": "_$0"},
     {"original": "myMethod", "obfuscated": "_$1"}
   ]
   ```
   This is what `flutter symbolize` reads.

3. **Can we hook into `flutter symbolize`?**
   If we emit the same JSON array format, `flutter symbolize` should be able to read it. This is the lowest-friction integration path.

4. **Native Crashlytics console deobfuscation?**
   This uses DWARF debug info, not the obfuscation symbol file. Generating DWARF-compatible info at kernel level is not feasible. Users would need our `refractor symbolicate` command instead.

---

## Recommended Approach

### Path A: Emit `--obfuscate`-compatible symbol file (recommended for v0.2.3)

**Create:** `lib/src/engine/symbol_format/dart_obfuscation_format.dart`

```dart
/// Converts a SymbolTable to the JSON array format used by
/// `dart compile --obfuscate --save-debugging-info`.
///
/// Output format:
/// [
///   {"original": "MyClass", "obfuscated": "_$0"},
///   {"original": "myMethod", "obfuscated": "_$1"}
/// ]
class DartObfuscationFormat {
  static String encode(SymbolTable table) {
    final entries = <Map<String, String>>[];
    for (final entry in table.toJson().entries) {
      entries.add({
        'original': entry.value,   // original name (value in our map)
        'obfuscated': entry.key,   // obfuscated name (key in our map)
      });
    }
    return const JsonEncoder.withIndent('  ').convert(entries);
  }
}
```

**Modify:** artifact handling / CLI output boundary

Add `--symbol-format` option:

```dart
..addOption(
  'symbol-format',
  help: 'Symbol map output format.',
  allowed: ['json', 'dart-obfuscation'],
  defaultsTo: 'json',
)
```

When `dart-obfuscation`, write the alternative format:

```dart
case Ok<BuildResult>():
  final format = argResults.option('symbol-format')!;
  final content = switch (format) {
    'dart-obfuscation' => DartObfuscationFormat.encode(result.value.symbolTable),
    _ => result.value.symbolTable.toJsonString(),
  };
  final symbolFile = File(config.symbolMapPath);
  symbolFile.parent.createSync(recursive: true);
  symbolFile.writeAsStringSync(content);
```

### Path B: Native Crashlytics integration (deferred)

Generating DWARF-compatible debug info at kernel level is too complex for this milestone. Deferred to a future version or handled by documenting a workflow using `refractor symbolicate`.

---

## Files to Create

### `lib/src/engine/symbol_format/dart_obfuscation_format.dart`

Pure engine-layer class. Converts `SymbolTable` → Dart obfuscation JSON array format.

---

## Files to Modify

### artifact handling layer

Add symbol-format selection logic through the future artifact boundary instead
of letting `BuildCommand` grow one-off file-writing branches.

---

## Tests

### Unit: `test/engine/symbol_format/dart_obfuscation_format_test.dart`

- Empty symbol table → `[]`
- Single entry → `[{"original": "X", "obfuscated": "Y"}]`
- Multiple entries → correct array of objects
- Round-trip: encode → decode → verify entries match original table
- Output is valid JSON

---

## Detailed Verification Checklist

- [ ] `dart analyze` — zero warnings
- [ ] `dart test` — all tests pass
- [ ] Output format matches `dart compile exe --obfuscate --save-debugging-info` structure
- [ ] `flutter symbolize` can read the generated file (manual verification)

---

## Additional Open Questions

- Should both formats always be emitted, or is it a choice via `--symbol-format`?
- Should the default format change from `json` to `dart-obfuscation`?
- Is the Dart obfuscation JSON format stable across SDK versions?
