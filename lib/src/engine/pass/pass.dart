import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/pass/pass_result.dart';

/// Base class for all obfuscation passes.
abstract class Pass {
  /// Human-readable name used in logging and CLI --passes flag.
  String get name;

  /// Run this pass over [component], mutating it in place.
  Future<PassResult> run(Component component);
}
