import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/pass/pass_result.dart';

/// Base class for all obfuscation passes.
abstract class Pass {
  /// Human-readable name used in logging and CLI --passes flag.
  String get name;

  /// Run this pass over [component], mutating it in place.
  ///
  /// Synchronous: passes mutate the shared [Component] in place and must run
  /// in a fixed order, so there is nothing to parallelize and no IO to await.
  /// A pass that one day needs real async work (e.g. an AI-backed name
  /// generator) should do that IO at its own boundary rather than make the
  /// whole pipeline async again.
  PassResult run(Component component);
}
