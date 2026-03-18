import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/runner/obfuscation_target.dart';
import 'package:refractor/src/utils/result.dart';

/// Base class for all obfuscation passes.
///
/// `R` is the result type — `void` for passes with no output,
/// `RenameMapping` for `RenamePass`, etc.
abstract class Pass<R> {
  /// Human-readable name used in logging and CLI --passes flag.
  String get name;

  /// Run this pass over [component], mutating it in place.
  Future<Result<R>> run(Component component, ObfuscationTarget target);
}
