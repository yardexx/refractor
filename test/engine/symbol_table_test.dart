import 'dart:convert';

import 'package:refractor/src/engine/symbol_table.dart';
import 'package:test/test.dart';

void main() {
  group('SymbolTable', () {
    test('records and resolves mappings in both directions', () {
      final table = SymbolTable()
        ..record('MyClass', r'_$0')
        ..record('myMethod', r'_$1');

      expect(table.original(r'_$0'), 'MyClass');
      expect(table.original(r'_$1'), 'myMethod');
      expect(table.obfuscated('MyClass'), r'_$0');
      expect(table.obfuscated('myMethod'), r'_$1');
      expect(table.size, 2);
    });

    test('returns null when mapping is missing', () {
      final table = SymbolTable();

      expect(table.original('missing'), isNull);
      expect(table.obfuscated('missing'), isNull);
    });

    test('exports pretty-printed JSON', () {
      final table = SymbolTable()..record('MyClass', r'_$0');

      final json = table.toJsonString();
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      expect(decoded, {r'_$0': 'MyClass'});
      expect(json, contains('\n'));
    });
  });
}
