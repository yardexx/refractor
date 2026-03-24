/// Refractor — Dart kernel obfuscation engine.
///
/// Public API barrel file for programmatic use of the obfuscation engine.
/// Has no dart:io dependency — import specific utils for file I/O.
library;

export 'src/engine/compiler/compiler.dart';
export 'src/engine/engine.dart';
export 'src/engine/kernel/kernel_io.dart';
export 'src/engine/obfuscation_target.dart';
export 'src/engine/pass.dart';
export 'src/engine/pass_runner.dart';
export 'src/engine/passes.dart';
export 'src/engine/passes/rename/model.dart';
export 'src/engine/passes/rename/name_generator/name_generator.dart';
export 'src/engine/symbol_table.dart';
