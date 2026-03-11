import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/passes/rename/model/generated_names.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_scope.dart';
import 'package:refractor/src/engine/passes/rename/name_generator/sequential_generator.dart'
    show SequentialGenerator;
import 'package:refractor/src/engine/passes/rename/name_generator/shuffled_generator.dart'
    show ShuffledGenerator;

/// Shared alphabet used by all name generators.
const String nameAlphabet =
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

/// Size of [nameAlphabet].
const int nameAlphabetSize = 52;

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
  /// Returns the next raw name string.
  String nextName();

  /// Generate names for everything in [scope].
  Future<GeneratedNames> generate(RenameScope scope) async {
    final families = scope.overrideFamilies;

    return GeneratedNames(
      familyNames: {
        for (final f in families.families) f: nextName(),
      },
      singletonNames: {
        for (final m in _allSingletons(scope)) m: nextName(),
      },
      classNames: {
        for (final c in scope.classScopes) c.node: nextName(),
      },
      variableNames: {
        for (final v in scope.variables) v: nextName(),
      },
    );
  }
}

/// Collects all singleton members (top-level + static) from a scope.
Iterable<Member> _allSingletons(RenameScope scope) sync* {
  yield* scope.topLevelMembers;
  for (final cs in scope.classScopes) {
    yield* cs.staticMembers;
    yield* cs.constructors;
  }
}
