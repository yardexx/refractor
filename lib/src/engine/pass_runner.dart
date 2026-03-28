import 'package:kernel/kernel.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:refractor/src/engine/pass.dart';

/// Runs a list of [Pass]es over a kernel [Component].
///
/// Runs passes in order and collects results. Continues after pass failures.
class PassRunner {
  PassRunner({
    required this.passes,
    this.logger,
  });
  final List<Pass> passes;
  final Logger? logger;

  /// Run all passes on [component] and return collected results.
  Future<PassResults> run(Component component) async {
    final results = PassResults();
    for (final pass in passes) {
      logger?.detail('Running pass: ${pass.name}');
      final execution = await pass.run(component);
      switch (execution) {
        case PassSucceeded(:final artifact, :final report):
          results.addReport(report);
          if (artifact != null) {
            results.addArtifact(pass.name, artifact);
          }
        case PassFailed(:final error, :final report):
          results
            ..addReport(report)
            ..addFailure(PassFailureRecord(passName: pass.name, error: error));
      }
      logger?.detail('Pass "${pass.name}" complete.');
    }
    return results;
  }
}
