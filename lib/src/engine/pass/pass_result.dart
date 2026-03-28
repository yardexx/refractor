import 'package:refractor/src/engine/pass/reporting/pass_artifact.dart';
import 'package:refractor/src/engine/pass/reporting/pass_report.dart';

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
