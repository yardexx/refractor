import 'package:refractor/refractor.dart' show RefractorEngine;
import 'package:refractor/src/engine/engine.dart' show RefractorEngine;
import 'package:refractor/src/exceptions/refractor_exception.dart';

/// Valid compilation targets for `dart compile`.
enum Target {
  exe('exe', ''),
  aot('aot-snapshot', '.aot'),
  jit('jit-snapshot', '.jit'),
  kernel('kernel', '.dill')
  ;

  const Target(this.value, this.extension);

  factory Target.fromString(String target) {
    switch (target) {
      case 'exe':
        return Target.exe;
      case 'aot':
        return Target.aot;
      case 'jit':
        return Target.jit;
      case 'kernel':
        return Target.kernel;
      default:
        throw BuildException('Invalid target: $target');
    }
  }

  final String value;
  final String extension;
}

/// Abstract interface for compiling Dart source to kernel and to target
/// formats.
///
/// Defined in the engine layer (pure) so that [RefractorEngine] can depend on
/// it without importing dart:io. Implemented in the IO layer by `DartCompiler`.
abstract class Compiler {
  /// Compile Dart source at [sourcePath] to kernel `.dill` at [outputPath].
  void compileToKernel(String sourcePath, String outputPath);

  /// Compile kernel `.dill` at [dillPath] to the given [target] format
  /// (e.g. `exe`, `aot-snapshot`, `jit-snapshot`) at [outputPath].
  void compileToTarget(String dillPath, String outputPath, Target target);
}
