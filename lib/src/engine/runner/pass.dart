import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/runner/pass_context.dart';

/// Base class for all obfuscation passes.
abstract class Pass {
  /// Human-readable name used in logging and CLI --passes flag.
  String get name;

  /// Run this pass over [component], mutating it in place.
  /// Use [context] to access shared state (symbol table, name generator,
  /// options).
  void run(Component component, PassContext context);
}
