# Pass System Architecture

## Historical Problem State

```
Pass.run(Component, PassContext) → void
```

- **`PassContext` is a god object**: holds `SymbolTable`, `PassOptions`,
  `projectRootUri`, `projectPackageName`, and `shouldObfuscateLibrary()`. It
  mixes inputs, outputs, and shared infrastructure.
- **`SymbolTable` is a side channel**: only `RenamePass` writes to it, but it is
  threaded through as shared mutable state. It is an output pretending to be
  context.
- **`PassOptions` is a shared bag**: `RenamePass` reads `preserveMain`, `seed`,
  `namingStrategy`. `StringEncryptPass` reads `stringExcludePatterns`. Each pass
  sees the other's options.
- **`PassRunner` knows about specific outputs**: it is coupled to artifact flow
  and previously relied on `Result<>` to control failure.
- **Generic pass output is awkward for artifact-less passes**: `Pass<void>` is
  mechanically valid, but it does not describe the domain clearly.

This section describes the pre-refactor pass system that motivated the current
design below. It is preserved as architecture context, not as current branch
truth.

## Proposed Architecture

### Core Principle

A pass is an execution unit:

- it takes options plus a component and target
- it runs
- it always produces reportable execution data
- it may optionally produce an artifact

The artifact is secondary. Execution is primary.

### Pass Interface

```dart
abstract class Pass {
  String get name;

  Future<PassResult> run(
    Component component,
    ObfuscationTarget target,
  );
}
```

This keeps the interface uniform for all passes. A pass that does not expose any
artifact is not forced into fake `void` typing.

### PassResult

The pass no longer returns `Result<>`. Instead it returns a sealed execution
object:

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

This makes pass failure part of normal pass execution data, not an out-of-band
wrapper.

### PassReport

Every pass execution carries a report:

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
}
```

`PassReport` is structured data:

- `passName` is the producer identity
- `metrics` are stable machine-readable counters
- `message` is a human-oriented summary, mainly for failures or no-op cases

Presentation labels do not belong here.

### PassArtifact

Artifacts are explicit and optional:

```dart
abstract class PassArtifact {
  const PassArtifact();
}
```

Each pass may define its own artifact type:

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

This is easier to understand than making artifact type the defining shape of all
passes.

### ObfuscationTarget (shared, read-only)

The one thing all passes need is the project/library targeting rule:

```dart
class ObfuscationTarget {
  ObfuscationTarget({
    required this.projectRootUri,
    required this.projectPackageName,
    required this.excludePatterns,
  });

  bool shouldObfuscateLibrary(Library library) { ... }
}
```

This is not pass-specific. It is a property of the project being obfuscated.
Every pass receives the same target.

### Per-Pass Options

Each pass defines its own options type. No shared bag.

```dart
class RenamePass extends Pass {
  RenamePass({required this.options});
  final RenamePassOptions options;

  @override
  Future<PassResult> run(
    Component component,
    ObfuscationTarget target,
  ) async {
    // collect → generate → allocate → apply
    // return PassSucceeded(
    //   artifact: RenameArtifact(mapping: mapping),
    //   report: ...
    // )
  }
}
```

```dart
class StringEncryptPass extends Pass {
  StringEncryptPass({this.xorKey = 0x5A, this.excludePatterns = const []});
  final int xorKey;
  final List<RegExp> excludePatterns;

  @override
  Future<PassResult> run(
    Component component,
    ObfuscationTarget target,
  ) async {
    // encrypt strings
    // return PassSucceeded(report: ...)
    // or PassFailed(error: ..., report: ...)
  }
}
```

Options are constructor parameters. The pass owns them.

### Open-Fail Runner

The runner is best-effort. It attempts every configured pass, records both
successes and failures, and continues after individual pass failures.

```dart
class PassRunner {
  PassRunner({required this.passes, this.logger});
  final List<Pass> passes;
  final Logger? logger;

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
}
```

### PassResults

`PassResults` collects three things:

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

The engine asks for specific artifacts by pass name and artifact type:

```dart
final renameArtifact = results.artifact<RenameArtifact>('rename');
final mapping = renameArtifact?.mapping;
```

### Open-Fail Principle

The pass pipeline follows an open-fail policy:

- every configured pass is attempted
- one failed pass does not block later passes
- failed passes produce reports and failure records
- failed passes do not contribute artifacts
- successful passes remain usable even in a partially failed build

This is intentionally a best-effort model. For now, passes are treated as
independent. Future passes must not assume earlier passes succeeded unless and
until explicit dependency management is added.

### Library Filtering

All passes need to know which libraries are user code. This is handled in one
place via `ObfuscationTarget`, threaded through `PassVisitor` and
`PassTransformer`.

`PassVisitor` and `PassTransformer` both take `ObfuscationTarget` and skip
non-user libraries automatically. No pass needs to reimplement library
filtering.
