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
    _run(['compile', 'kernel', '-o', outputPath, sourcePath]);
  }

  @override
  void compileToTarget(String dillPath, String outputPath, Target target) {
    // `dart compile` for snapshot targets may ignore `-o` when the input is a
    // `.dill` file and instead emit next to the kernel path (`jit-snapshot`
    // does). Clear both locations first so a leftover file from an earlier
    // build is never mistaken for this build's output.
    final expectedOutput = File(outputPath);
    final fallbackOutput = target.extension.isEmpty
        ? null
        : File('$dillPath${target.extension}');
    _deleteIfExists(expectedOutput);
    if (fallbackOutput != null) _deleteIfExists(fallbackOutput);

    // Options must precede the input: `dart compile jit-snapshot` treats
    // everything after the entry point as training arguments for the run it
    // performs at build time, so a trailing `-o <out>` would reach the
    // program's `main` as `args`.
    _run(['compile', target.value, '-o', outputPath, dillPath]);

    if (expectedOutput.existsSync()) {
      return;
    }

    if (fallbackOutput != null && fallbackOutput.existsSync()) {
      fallbackOutput.renameSync(outputPath);
      return;
    }

    throw CompilationException(
      '`dart compile ${target.value}` reported success but produced no '
      'output at $outputPath',
    );
  }

  void _deleteIfExists(File file) {
    try {
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException catch (e) {
      throw CompilationException(
        'Could not remove stale output ${file.path}: ${e.message}',
        cause: e,
      );
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
