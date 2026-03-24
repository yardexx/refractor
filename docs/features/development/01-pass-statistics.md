# Pass Reports

**Status:** active
**Owner:** maintainers
**Last reviewed:** 2026-03-24
**Applies to:** `v0.2.0`
**Related:** [../../roadmap/v0.2.0.md](../../roadmap/v0.2.0.md), [02-reporters.md](02-reporters.md), [../README.md](../README.md)

## Goal

Add structured pass reports while making pass execution outcomes explicit and
keeping artifact production optional.

## Scope

Included:

- explicit pass execution result model
- structured reports and optional artifacts
- build-level aggregation of pass outcomes
- build-layer access to pass outcomes for later reporting

Not included:

- dedicated reporter abstractions or output formatting
- multi-target reporter architecture
- server upload or remote reporting
- explicit pass dependency graph in `v0.2.0`

## Acceptance Criteria

- pass execution outcomes are represented explicitly
- successful and failed passes are both reportable
- artifact-less passes do not require awkward fake typing
- build results expose pass outcomes clearly for downstream consumers

## Test Plan

- unit coverage for new pass result models
- runner tests for open-fail behavior
- build-result aggregation tests
- command-level coverage for fail-close exit behavior

## Open Questions

- should open-fail behavior remain the default long term, or become configurable
  once pass dependencies increase?

Desired properties:

- pass success is reportable
- pass failure is reportable
- one failed pass does not block other passes
- some passes may produce artifacts for downstream engine use
- passes without artifacts should not need fake `void` typing

This feature changes the pass contract, but it must not change the underlying
transformation behavior of successful passes or symbol map semantics.

---

## Core Idea

A pass is an execution unit.

Every pass:

- runs against a component and target
- produces a `PassResult`
- always emits a `PassReport`
- may optionally emit a `PassArtifact`

That leads to one clear model:

```dart
abstract class Pass {
  String get name;

  Future<PassResult> run(
    Component component,
    ObfuscationTarget target,
  );
}
```

Where execution is sealed:

```dart
sealed class PassResult {
  const PassResult({
    required this.report,
  });

  final PassReport report;
}

final class PassSucceeded extends PassResult {
  const PassSucceeded({
    required super.report,
    this.artifact,
  });

  final PassArtifact? artifact;
}

final class PassFailed extends PassResult {
  const PassFailed({
    required super.report,
    required this.error,
  });

  final Exception error;
}
```

And artifacts are explicit:

```dart
abstract class PassArtifact {
  const PassArtifact();
}
```

This is the architectural center of the feature.

---

## Open-Fail Principle

This feature adopts an **open-fail** pass pipeline:

- every configured pass is attempted
- a failed pass is recorded and reported
- one failed pass does **not** stop later passes from running
- only artifacts from successful passes are stored for downstream engine use

Rationale:

- reporting is more valuable when it includes both successes and failures
- current passes are independent enough to support best-effort execution
- future pass dependencies can be added explicitly if needed

Non-goal for v0.2.0:

- dependency management between passes

So the rule for now is simple:

**Passes must not assume earlier passes succeeded.**

---

## Previous Architecture

**`Pass<R>`** (`lib/src/engine/runner/pass.dart`):

- returns `Future<Result<R>>`
- success/error is expressed through `Result<>`
- passes with no artifact fall back to `void`

**`PassRunner`** (`lib/src/engine/runner/pass_runner.dart`):

- stops on first error
- collects only successful artifacts

**`PassResults`** (`lib/src/engine/runner/pass_results.dart`):

- stores heterogeneous pass artifacts by pass name
- has no reporting or failure data

**`BuildResult`** (`lib/src/engine/engine.dart`):

- carries output path, symbol table, passes run
- has no pass execution summaries

This was the architecture before this feature. It explains the change being
specified here; it is not the current branch state anymore.

---

## New Data Model

### `lib/src/engine/runner/pass_metric.dart` (new)

```dart
class PassMetric {
  const PassMetric({
    required this.key,
    required this.value,
  });

  final String key;
  final int value;
}
```

Rules:

- stable machine-readable data only
- no display labels here
- reporters map keys to presentation

### `lib/src/engine/runner/pass_report.dart` (new)

```dart
class PassReport {
  const PassReport({
    required this.passName,
    this.metrics = const [],
    this.message,
  });

  final String passName;
  final List<PassMetric> metrics;
  final String? message;

  int get totalCount => metrics.fold(0, (sum, m) => sum + m.value);

  bool get isEmpty => metrics.isEmpty && message == null;
}
```

Rules:

- `passName` is the stable producer identity
- `metrics` preserve authored order
- `message` is the human-oriented summary slot, especially for failures
- this remains structured data, not preformatted CLI output

### `lib/src/engine/runner/pass_artifact.dart` (new)

```dart
abstract class PassArtifact {
  const PassArtifact();
}
```

Rules:

- artifacts are machine-consumable outputs
- artifacts are optional by design
- each pass may define its own artifact type

Examples:

```dart
final class RenameArtifact extends PassArtifact {
  const RenameArtifact({
    required this.mapping,
  });

  final RenameMapping mapping;
}
```

```dart
final class StringEncryptionArtifact extends PassArtifact {
  const StringEncryptionArtifact({
    required this.encryptedCount,
    required this.helperInjected,
  });

  final int encryptedCount;
  final bool helperInjected;
}
```

### `lib/src/engine/runner/pass_result.dart` (new)

```dart
sealed class PassResult {
  const PassResult({
    required this.report,
  });

  final PassReport report;
}

final class PassSucceeded extends PassResult {
  const PassSucceeded({
    required super.report,
    this.artifact,
  });

  final PassArtifact? artifact;
}

final class PassFailed extends PassResult {
  const PassFailed({
    required super.report,
    required this.error,
  });

  final Exception error;
}
```

Rules:

- every execution always yields a `PassReport`
- only `PassSucceeded` may carry an artifact
- `PassFailed` carries the raw exception for debugging/logging purposes

---

## Pass Interface

### `lib/src/engine/runner/pass.dart`

Change from:

```dart
abstract class Pass<R> {
  String get name;
  Future<Result<R>> run(Component component, ObfuscationTarget target);
}
```

to:

```dart
abstract class Pass {
  String get name;

  Future<PassResult> run(
    Component component,
    ObfuscationTarget target,
  );
}
```

Why:

- removes `Result<>`, which is not a good fit for open-fail execution
- removes awkward generic `void` artifacts
- centers the contract on what every pass actually does: execute and report
- keeps artifacts explicit and optional

---

## Pass Implementations

### `lib/src/engine/passes/rename/rename_pass.dart`

`RenamePass` no longer expresses its output through a type parameter. It emits a
success execution with a `RenameArtifact`.

```dart
final class RenameArtifact extends PassArtifact {
  const RenameArtifact({
    required this.mapping,
  });

  final RenameMapping mapping;
}
```

Success path:

```dart
return PassSucceeded(
  artifact: RenameArtifact(mapping: mapping),
  report: PassReport(
    passName: name,
    metrics: [
      PassMetric(key: 'classes', value: mapping.classes.length),
      PassMetric(key: 'members', value: mapping.members.length),
      PassMetric(key: 'variables', value: mapping.variables.length),
    ],
  ),
);
```

Failure path:

```dart
return PassFailed(
  error: e,
  report: PassReport(
    passName: name,
    message: e.toString(),
  ),
);
```

### `lib/src/engine/passes/string_encrypt/string_encrypt_pass.dart`

`StringEncryptPass` follows the same contract. It may succeed with no artifact,
or it may return a dedicated artifact if future engine consumers need one.

Success with work performed:

```dart
return PassSucceeded(
  report: PassReport(
    passName: name,
    metrics: [
      PassMetric(key: 'strings_encrypted', value: encryptedCount),
    ],
  ),
);
```

Success with artifact, if needed later:

```dart
return PassSucceeded(
  artifact: StringEncryptionArtifact(
    encryptedCount: encryptedCount,
    helperInjected: helperInjected,
  ),
  report: PassReport(
    passName: name,
    metrics: [
      PassMetric(key: 'strings_encrypted', value: encryptedCount),
    ],
  ),
);
```

Failure path:

```dart
return PassFailed(
  error: e,
  report: PassReport(
    passName: name,
    message: e.toString(),
  ),
);
```

---

## Runner Changes

### `lib/src/engine/runner/pass_runner.dart`

The runner becomes best-effort and switches on `PassResult`:

```dart
Future<PassResults> run(
  Component component,
  ObfuscationTarget target,
) async {
  final results = PassResults();

  for (final pass in passes) {
    logger?.detail('Running pass: ${pass.name}');
    final execution = await pass.run(component, target);

    switch (execution) {
      case PassSucceeded(:final artifact, :final report):
        results.addReport(report);
        if (artifact != null) {
          results.addArtifact(pass.name, artifact);
        }
      case PassFailed(:final error, :final report):
        results.addReport(report);
        results.addFailure(
          PassFailureRecord(
            passName: pass.name,
            error: error,
          ),
        );
    }
  }

  return results;
}
```

Required behavior:

- all configured passes are attempted in order
- every attempted pass contributes exactly one report
- failed passes contribute a failure record and no artifact
- successful passes may contribute one artifact keyed by `pass.name`

---

## Result Aggregation

### `lib/src/engine/runner/pass_results.dart`

`PassResults` aggregates three things:

```dart
class PassResults {
  final Map<String, PassArtifact> _artifacts = {};
  final List<PassReport> reports = [];
  final List<PassFailureRecord> failures = [];

  void addArtifact(String passName, PassArtifact artifact) {
    _artifacts[passName] = artifact;
  }

  T? artifact<T extends PassArtifact>(String passName) {
    final artifact = _artifacts[passName];
    return artifact is T ? artifact : null;
  }
}
```

Invariants:

- `reports` preserve pass execution order
- `pass.name` is unique within a pipeline run
- artifact lookup stays keyed by pass name
- reports and artifacts are intentionally separate concerns

---

## Engine Changes

### `lib/src/engine/engine.dart`

`BuildResult` is extended to carry:

- `reports`
- `failures`

The engine continues to derive the symbol table only from successful rename
output:

```dart
final renameArtifact = results.artifact<RenameArtifact>('rename');
final mapping = renameArtifact?.mapping;
```

Rules:

- a failed rename pass does not block later passes
- symbol table generation only uses successful rename output
- final output generation stops if any pass reports failure

---

## Command Boundary

`BuildCommand` receives `BuildResult`, but report rendering is deferred to the
follow-up reporter feature.

Required behavior in this feature:

- build exits nonzero if any pass failed
- structured report data remains available from `BuildResult`
- engine-layer report data stays presentation-neutral

Deferred to `02-reporters.md`:

- CLI formatting of success and failure summaries
- metric-label presentation policy
- omission/filtering policy for no-op reports

---

## Testing

### New tests

- `PassResult`
  - success with artifact
  - success without artifact
  - failure with error and report
- `PassReport`
  - metric ordering preserved
  - `message`-only report is non-empty
  - `totalCount` is correct
- `PassResults`
  - artifacts stored only for successful passes
  - reports collected for every attempted pass
  - failures collected in order
  - keyed artifact lookup remains unchanged

### Updated tests

- `PassRunner`
  - later passes still run after an earlier pass fails
  - failed passes do not suppress later successful artifacts
- `RenamePass`
  - returns `PassSucceeded` with `RenameArtifact`
  - returns `PassFailed` with failure report on error
- `StringEncryptPass`
  - returns success/no-op/failure executions as appropriate
  - optionally returns a `StringEncryptionArtifact` if implementation needs one
- `RefractorEngine`
  - pass failures still return `BuildResult`
  - final output generation is skipped when any pass fails
  - symbol table is built only from successful rename output
  - reports and failures are wired through
- `BuildCommand`
  - exit code is nonzero when any pass failed

---

## Assumptions

- `PassMetric` stays as a dedicated class for now
- passes are treated as independent in v0.2.0
- no pass dependency graph is added in this feature
- `PassReport.message` is the default place for human-oriented failure summaries
- artifacts are optional and explicit, not encoded through generics
- failed pass runs may still return `BuildResult`, but they do not emit final
  output artifacts
