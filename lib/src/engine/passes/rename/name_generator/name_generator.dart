import 'package:refractor/src/engine/passes/rename/model/generated_names.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_scope.dart';
import 'package:refractor/src/engine/passes/rename/name_generator/sequential_generator.dart' show SequentialGenerator;
import 'package:refractor/src/engine/passes/rename/name_generator/shuffled_generator.dart' show ShuffledGenerator;

/// Abstract name generator — the creative part of rename allocation.
///
/// Takes a [RenameScope], produces raw name strings for every slot.
/// This is where strategy lives:
/// - [SequentialGenerator] — deterministic a, b, ..., aa, ab, ...
/// - [ShuffledGenerator] — seeded random permutation
/// - (planned) AI generator — sends scope to AI for plausible names
///
/// `generate(scope)` instead of `next()` because an AI generator needs
/// the full picture to produce semantically coherent names.
abstract class NameGenerator {
  /// Generate names for everything in [scope].
  Future<GeneratedNames> generate(RenameScope scope);
}
