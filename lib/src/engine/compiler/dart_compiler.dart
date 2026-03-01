import 'package:refractor/src/engine/compiler/compiler.dart';
import 'package:refractor/src/utils/process_runner.dart';

/// Compiles Dart source to kernel and to target formats using the `dart` CLI.
class DartCompiler implements Compiler {
  DartCompiler({this.verbose = false});
  final bool verbose;

  @override
  void compileToKernel(String sourcePath, String outputPath) {
    runProcess(
      'dart',
      ['compile', 'kernel', sourcePath, '-o', outputPath],
      verbose: verbose,
    );
  }

  @override
  void compileToTarget(String dillPath, String outputPath, Target target) {
    runProcess(
      'dart',
      ['compile', target.value, dillPath, '-o', outputPath],
      verbose: verbose,
    );
  }
}
