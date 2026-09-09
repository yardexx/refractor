import 'package:refractor/src/engine/pass/reporting/pass_artifact.dart';
import 'package:refractor/src/engine/pass/reporting/pass_report.dart';

/// Collects heterogeneous results from pass runs.
///
/// The engine asks for specific results by pass name + type:
/// ```dart
/// final rename = results.artifact<RenameArtifact>('rename');
/// ```
class PassFailureRecord {
  const PassFailureRecord({
    required this.passName,
    required this.error,
  });

  final String passName;
  final Exception error;

  Map<String, Object?> toJson() => {
    'pass_name': passName,
    'error': error.toString(),
  };
}

class PassResults {
  PassResults({
    List<PassReport>? reports,
    List<PassFailureRecord>? failures,
    List<String>? skipped,
  }) : reports = reports ?? [],
       failures = failures ?? [],
       skipped = skipped ?? [];

  final Map<String, PassArtifact> _artifacts = {};
  final List<PassReport> reports;
  final List<PassFailureRecord> failures;

  /// Names of passes that were not run because an earlier pass failed
  /// (fail-fast). Distinct from [failures]: a skipped pass never executed.
  final List<String> skipped;

  Map<String, PassArtifact> get artifacts => Map.unmodifiable(_artifacts);

  void addArtifact(String passName, PassArtifact artifact) {
    _artifacts[passName] = artifact;
  }

  T? artifact<T extends PassArtifact>(String passName) {
    final artifact = _artifacts[passName];
    return artifact is T ? artifact : null;
  }

  void addReport(PassReport report) {
    reports.add(report);
  }

  void addFailure(PassFailureRecord failure) {
    failures.add(failure);
  }

  void addSkipped(String passName) {
    skipped.add(passName);
  }

  Map<String, Object?> toJson() => {
    'artifacts': {
      for (final entry in _artifacts.entries) entry.key: entry.value.toJson(),
    },
    'reports': [for (final report in reports) report.toJson()],
    'failures': [for (final failure in failures) failure.toJson()],
    'skipped': skipped,
  };
}
