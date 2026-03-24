# `--dry-run`

**Status:** planned
**Owner:** maintainers
**Last reviewed:** 2026-03-23
**Applies to:** `v0.2.3` candidate scope
**Related:** [../../roadmap/v0.2-overview.md](../../roadmap/v0.2-overview.md), [../../roadmap/v0.2.0.md](../../roadmap/v0.2.0.md)

## Goal

Allow users to run the obfuscation pipeline up to pass execution without the
final artifact production step. The command should show what would happen
without committing to a full build.

## Scope

Included:

- `--dry-run` CLI flag
- engine support for skipping final output generation
- useful summary output for passes and symbol activity

Not included:

- a fake successful output artifact
- release-grade symbolication or crash-reporting changes

## Acceptance Criteria

- `--dry-run` executes compile-to-kernel and pass execution
- final output compilation is skipped
- users get a clear summary of what would change
- normal build behavior remains unchanged without `--dry-run`

## Test Plan

- engine tests for skipped write/compile behavior
- CLI-level verification of dry-run messaging
- regression checks for normal builds

## Open Questions

- should symbol maps be written during dry-run or only summarized?
- should dry-run still persist temporary intermediate artifacts for debugging?

## Current Architecture

- `RefractorEngine.run()` is async and returns `Future<BuildResult>`
- pipeline: compile to kernel → load → run passes → write obfuscated kernel →
  compile to target
- `BuildRequest` bundles IO parameters (`input`, `output`, `target`,
  `workDirectory`, `projectRootUri`, `projectPackageName`)
- `BuildResult` currently contains `outputPath`, `symbolTable`, `passesRun`,
  `reports`, and `failures`
- `BuildCommand` writes the symbol map via the CLI-layer
  `SymbolTableIo.writeToPath()` extension

---

## Files to Modify

### `lib/src/engine/engine.dart`

Add `dryRun` field to `BuildRequest`:

```dart
class BuildRequest {
  const BuildRequest({
    // ... existing fields
    this.dryRun = false,
  });
  final bool dryRun;
  // ... existing fields
}
```

In `RefractorEngine.run()`, skip steps 3-4 (write obfuscated kernel + compile to target) when `dryRun` is true. Steps 1-2 (compile to kernel + run passes) still execute so we get the symbol table and can report what would happen.

```dart
if (!request.dryRun) {
  // 3. Write obfuscated kernel.
  kernelIO.write(obfuscated, obfuscatedDillPath);

  // 4. Compile to target.
  switch (request.target) { ... }
}
```

### `lib/src/cli/commands/build_command.dart`

Add `--dry-run` flag:

```dart
..addFlag(
  'dry-run',
  help: 'Run obfuscation passes without final compilation. '
      'Displays symbol counts.',
  negatable: false,
)
```

Pass to `BuildRequest`:

```dart
final request = BuildRequest(
  // ... existing fields
  dryRun: argResults.flag('dry-run'),
);
```

Adjust output — skip symbol map file write, show different message:

```dart
if (argResults.flag('dry-run')) {
  logger.info('Dry run complete. No output written.');
  logger.info('Passes: ${result.passesRun.join(", ")}');
  logger.info('Symbols renamed: ${result.symbolTable.size}');
} else {
  result.symbolTable.writeToPath(config.symbolMapPath);
  logger.success('Build complete: ${result.outputPath}');
}
```

---

## Tests

### Unit: `test/engine/engine_test.dart`

- Engine with `dryRun: true` does NOT call `compiler.compileToTarget` (use mock/verify)
- Engine with `dryRun: true` does NOT call `kernelIO.write` for the obfuscated kernel
- Engine with `dryRun: true` still runs passes and returns a populated `BuildResult`
- Engine with `dryRun: false` behaves as before

---

## Verification Checklist

- [ ] `dart analyze` — zero warnings
- [ ] `dart test` — all tests pass
- [ ] `refractor build --dry-run` on a sample project shows symbol count, no output file
- [ ] `refractor build` (without --dry-run) still works as before
