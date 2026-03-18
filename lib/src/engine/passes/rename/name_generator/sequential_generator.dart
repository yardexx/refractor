import 'package:refractor/src/engine/passes/rename/name_generator/name_generator.dart';

/// Generates sequential names: `a`, `b`, ..., `z`, `A`, ..., `Z`,
/// `aa`, `ab`, etc.
///
/// Deterministic and simple — good for tests.
class SequentialGenerator extends NameGenerator {
  int _counter = 0;

  @override
  String nextName() {
    var n = _counter++;
    final chars = <int>[];
    do {
      chars.insert(0, nameAlphabet.codeUnitAt(n % nameAlphabetSize));
      n = n ~/ nameAlphabetSize - 1;
    } while (n >= 0);
    return String.fromCharCodes(chars);
  }
}
