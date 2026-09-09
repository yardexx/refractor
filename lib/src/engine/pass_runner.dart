import 'package:kernel/kernel.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:refractor/src/engine/pass.dart';

/// Runs a list of [Pass]es over a kernel [Component].
///
/// Runs passes in order and collects results. Fail-fast: the first pass failure
/// stops the run. Every pass shares one mutable component, so a failed pass may
/// have partially mutated it; later passes must not observe that state. The
/// remaining passes are recorded as skipped and the engine publishes nothing.
class PassRunner {
  PassRunner({
    required this.passes,
    this.logger,
  });
  final List<Pass> passes;
  final Logger? logger;

  /// Run passes on [component] until one fails, and return collected results.
  Future<PassResults> run(Component component) async {
    final results = PassResults();
    for (var index = 0; index < passes.length; index++) {
      final pass = passes[index];
      logger?.detail('Running pass: ${pass.name}');
      final execution = await pass.run(component);
      switch (execution) {
        case PassSucceeded(:final artifact, :final report):
          results.addReport(report);
          if (artifact != null) {
            results.addArtifact(pass.name, artifact);
          }
          logger?.detail('Pass "${pass.name}" complete.');
        case PassFailed(:final error, :final report):
          results
            ..addReport(report)
            ..addFailure(PassFailureRecord(passName: pass.name, error: error));
          logger?.detail('Pass "${pass.name}" failed; stopping.');
          _recordSkipped(results, from: index + 1);
          return results;
      }
    }
    return results;
  }

  void _recordSkipped(PassResults results, {required int from}) {
    for (final pass in passes.skip(from)) {
      results.addSkipped(pass.name);
      logger?.detail('Pass "${pass.name}" skipped: an earlier pass failed.');
    }
  }
}
