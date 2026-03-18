import 'package:kernel/kernel.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:refractor/src/engine/runner/obfuscation_target.dart';
import 'package:refractor/src/engine/runner/pass.dart';
import 'package:refractor/src/engine/runner/pass_results.dart';
import 'package:refractor/src/utils/result.dart';

/// Runs a list of [Pass]es over a kernel [Component].
///
/// Runs passes in order and collects results. Stops on first error.
class PassRunner {
  PassRunner({
    required this.passes,
    this.logger,
  });
  final List<Pass<dynamic>> passes;
  final Logger? logger;

  /// Run all passes on [component] and return collected results.
  Future<Result<PassResults>> run(
    Component component,
    ObfuscationTarget target,
  ) async {
    final results = PassResults();
    for (final pass in passes) {
      logger?.detail('Running pass: ${pass.name}');
      final result = await pass.run(component, target);
      switch (result) {
        case Ok(:final value):
          results.add(pass.name, value);
        case Error(:final error):
          return Result.error(error);
      }
      logger?.detail('Pass "${pass.name}" complete. ');
    }
    return Result.ok(results);
  }
}
