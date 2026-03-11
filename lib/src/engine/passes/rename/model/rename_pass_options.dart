import 'package:refractor/src/engine/passes/rename/rename_pass.dart'
    show RenamePass;

/// Per-pass options for [RenamePass].
///
/// No shared bag — the pass owns its options via constructor injection.
class RenamePassOptions {
  const RenamePassOptions({
    this.preserveMain = true,
    this.seed,
    this.namingStrategy = NamingStrategy.shuffled,
  });

  /// If true, the top-level `main` procedure is not renamed.
  final bool preserveMain;

  /// Seed for deterministic name generation.
  /// If null, derived from project name.
  final int? seed;

  /// Strategy for generating obfuscated names.
  final NamingStrategy namingStrategy;
}

/// Strategy for generating obfuscated names.
enum NamingStrategy { shuffled, sequential }
