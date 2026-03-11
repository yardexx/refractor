import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/passes/rename/model/generated_names.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_scope.dart';
import 'package:refractor/src/engine/passes/rename/name_generator/name_generator.dart';

/// Generates sequential names: `a`, `b`, ..., `z`, `A`, ..., `Z`,
/// `aa`, `ab`, etc.
///
/// Deterministic and simple — good for tests.
class SequentialGenerator extends NameGenerator {
  int _counter = 0;

  /// Returns the next name in the sequential sequence.
  String nextName() {
    var n = _counter++;
    final chars = <int>[];
    do {
      chars.insert(0, _alphabet.codeUnitAt(n % _alphabetSize));
      n = n ~/ _alphabetSize - 1;
    } while (n >= 0);
    return String.fromCharCodes(chars);
  }

  @override
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

  static const String _alphabet =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const int _alphabetSize = 52;
}

/// Collects all singleton members (top-level + static) from a scope.
Iterable<Member> _allSingletons(RenameScope scope) sync* {
  yield* scope.topLevelMembers;
  for (final cs in scope.classScopes) {
    yield* cs.staticMembers;
    yield* cs.constructors;
  }
}
