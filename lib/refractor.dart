/// Refractor — Dart kernel obfuscation engine.
///
/// Public API barrel file for programmatic use of the obfuscation engine.
/// Has no dart:io dependency — import specific utils for file I/O.
library;

export 'src/engine/compiler/compiler.dart';
export 'src/engine/engine.dart';
export 'src/engine/kernel/kernel_io.dart';
export 'src/engine/passes/rename/model/rename_mapping.dart';
export 'src/engine/passes/rename/model/rename_pass_options.dart';
export 'src/engine/passes/rename/name_generator/name_generator.dart';
export 'src/engine/passes/rename/rename_pass.dart';
export 'src/engine/passes/string_encrypt/string_encrypt_pass.dart';
export 'src/engine/runner/obfuscation_target.dart';
export 'src/engine/runner/pass.dart';
export 'src/engine/runner/pass_results.dart';
export 'src/engine/runner/pass_runner.dart';
export 'src/engine/symbol_table.dart';
