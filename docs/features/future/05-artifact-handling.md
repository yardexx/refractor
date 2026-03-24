# Artifact Handling

**Status:** future
**Owner:** maintainers
**Last reviewed:** 2026-03-24
**Applies to:** post-`v0.2.0` operator workflow scope
**Related:** [../../roadmap/v0.2-overview.md](../../roadmap/v0.2-overview.md), [03-symbolicate.md](03-symbolicate.md), [04-crashlytics-symbol-format.md](04-crashlytics-symbol-format.md), [../README.md](../README.md)

## Goal

Introduce a dedicated artifact-handling boundary for build outputs that are not
the final compiled binary itself, such as symbol maps, report files, or bundled
archives.

## Scope

Included:

- define responsibilities for writing auxiliary build artifacts
- keep artifact file creation out of command bodies where practical
- support multiple artifact shapes such as `.json`, `.zip`, or grouped output
  bundles

Not included:

- changing engine-layer data models just to support file IO
- remote upload flows
- replacing the compiler or kernel output path handling

## Acceptance Criteria

- artifact writing has one obvious ownership boundary
- commands no longer need one-off logic for each new artifact type
- symbol-map output, report output, and future bundles can share one coherent
  artifact story

## Test Plan

- unit tests for artifact-writing behavior
- command-level verification for configured artifact outputs
- regression checks that engine-layer data remains presentation-neutral and IO-free

## Open Questions

- should artifact handling be a simple utility layer or a configurable handler
  abstraction?
- should bundling formats such as `.zip` be first-class, or built from smaller
  artifact writers?
- should artifact generation be explicit in config, implicit by enabled
  features, or both?

This feature exists because `BuildCommand` currently writes the symbol map
directly. That is acceptable for one artifact, but it does not scale well once
report files, alternate symbol formats, or bundled outputs are added.

---

## Desired Outcome

By the end of this feature:

- `BuildCommand` remains an orchestration boundary, not an ever-growing file
  emission layer
- artifact creation is explicit and easy to extend
- future symbolication and crash-reporting work can depend on a stable artifact
  boundary instead of ad hoc command writes

---

## Design Direction

The artifact layer should sit outside the engine and consume already-produced
data such as:

- `BuildResult`
- `SymbolTable`
- rendered report output

Possible shapes:

```dart
abstract class BuildArtifactHandler {
  Future<void> write(BuildResult result);
}
```

or a smaller utility-oriented approach:

```dart
final class BuildArtifacts {
  Future<void> writeSymbolMap(...);
  Future<void> writeReport(...);
  Future<void> writeBundle(...);
}
```

The exact abstraction can stay small. The key rule is:

**Auxiliary artifact creation should have a dedicated boundary before multiple
artifact types accumulate in `BuildCommand`.**
