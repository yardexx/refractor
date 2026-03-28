import 'package:refractor/src/engine/passes/rename/planning/name_generator/rename_name_request.dart';
import 'package:refractor/src/engine/passes/rename/planning/name_generator/sequential_generator.dart'
    show SequentialGenerator;
import 'package:refractor/src/engine/passes/rename/planning/name_generator/shuffled_generator.dart'
    show ShuffledGenerator;

/// Shared alphabet used by all name generators.
const String nameAlphabet =
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

/// Size of [nameAlphabet].
const int nameAlphabetSize = 52;

/// Abstract name generator — the creative part of rename allocation.
///
/// Takes [RenameNameRequest]s and produces raw name strings for each request.
/// This is where strategy lives:
/// - [SequentialGenerator] — deterministic a, b, ..., aa, ab, ...
/// - [ShuffledGenerator] — seeded random permutation
/// - (planned) AI generator — sends scope to AI for plausible names
///
/// `generateNames(slots)` instead of `next()` because an AI generator needs
/// the full picture to produce semantically coherent names.
abstract class NameGenerator {
  /// Returns the next raw name string.
  String nextName();

  /// Generate names for everything in [requests].
  Future<Map<RenameNameRequest, String>> generateNames(
    List<RenameNameRequest> requests,
  ) async {
    return {
      for (final request in requests) request: nextName(),
    };
  }
}
