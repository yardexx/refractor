import 'dart:io';

import 'package:refractor/src/engine/compiler/compiler.dart';
import 'package:refractor/src/exceptions/refractor_exception.dart';
import 'package:refractor/src/utils/process_runner.dart';

/// Compiles Dart source to kernel and to target formats using the `dart` CLI.
class DartCompiler implements Compiler {
  DartCompiler({this.verbose = false});
  final bool verbose;

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
      runProcess('dart', arguments, verbose: verbose);
    } on ProcessException catch (e) {
      throw CompilationException('Compilation failed: $e', cause: e);
    }
  }
}
