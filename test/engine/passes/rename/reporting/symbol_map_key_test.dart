import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/passes/rename/reporting/symbol_map_key.dart';
import 'package:test/test.dart';

void main() {
  group('SymbolMapKey.forName', () {
    test('public name maps to its text', () {
      expect(SymbolMapKey.forName(Name('a')), 'a');
    });

    test('private name is qualified by its library import URI', () {
      final library = Library(
        Uri.parse('package:app/app.dart'),
        fileUri: Uri.parse('package:app/app.dart'),
      );

      expect(
        SymbolMapKey.forName(Name('_a', library)),
        'package:app/app.dart::_a',
      );
    });
  });
}
