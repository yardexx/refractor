import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:refractor/src/engine/compiler/compiler.dart';
import 'package:refractor/src/exceptions/refractor_exception.dart';
import 'package:refractor/src/utils/process_runner.dart';

/// Compiles Dart source to kernel and to target formats using the `dart` CLI.
class DartCompiler implements Compiler {
  DartCompiler({Logger? logger}) : _logger = logger;

  /// When set, the underlying `dart compile` commands and their output are
  /// logged at the verbose level.
  final Logger? _logger;

  @override
  void compileToKernel(String sourcePath, String outputPath) {
    _run(['compile', 'kernel', sourcePath, '-o', outputPath]);
  }

  @override
  void compileToTarget(String dillPath, String outputPath, Target target) {
    _run(['compile', target.value, dillPath, '-o', outputPath]);

    // `dart compile` for snapshot targets may ignore `-o` when the input is a
    // `.dill` file and instead emit next to the kernel path.
    final expectedOutput = File(outputPath);
    if (expectedOutput.existsSync()) {
      return;
    }

    final fallbackOutput = File('$dillPath${target.extension}');
    if (fallbackOutput.existsSync()) {
      fallbackOutput.renameSync(outputPath);
    }
  }

  void _run(List<String> arguments) {
    try {
      runProcess('dart', arguments, logger: _logger);
    } on ProcessException catch (e) {
      throw CompilationException('Compilation failed: $e', cause: e);
    }
  }
}
