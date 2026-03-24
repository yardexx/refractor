import 'package:refractor/src/engine/pass/pass_artifact.dart';
import 'package:refractor/src/engine/pass/pass_report.dart';

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
}

class PassResults {
  PassResults({
    List<PassReport>? reports,
    List<PassFailureRecord>? failures,
  }) : reports = reports ?? [],
       failures = failures ?? [];

  final Map<String, PassArtifact> _artifacts = {};
  final List<PassReport> reports;
  final List<PassFailureRecord> failures;

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
}
