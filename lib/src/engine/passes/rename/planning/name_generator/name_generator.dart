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

  /// Generate names for everything in [requests], never handing out one of
  /// the [reserved] names.
  ///
  /// Synchronous: the built-in strategies are pure computation. A future
  /// AI-backed generator that needs network IO should perform that IO behind
  /// its own async method and resolve it before planning, rather than making
  /// this method — and the whole pass pipeline above it — async again.
  Map<RenameNameRequest, String> generateNames(
    List<RenameNameRequest> requests, {
    Set<String> reserved = const {},
  }) {
    String nextFreeName() {
      var name = nextName();
      while (reserved.contains(name)) {
        name = nextName();
      }
      return name;
    }

    return {
      for (final request in requests) request: nextFreeName(),
    };
  }
}
