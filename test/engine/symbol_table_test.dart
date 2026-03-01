import 'dart:convert';
import 'dart:io';

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

    test('writes symbol map to disk', () async {
      final table = SymbolTable()..record('MyClass', r'_$0');
      final dir = await Directory.systemTemp.createTemp('symbol_table_test_');
      final file = File('${dir.path}/maps/symbols.json');

      table.writeToFile(file.path);

      expect(file.existsSync(), isTrue);
      final decoded =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(decoded, {r'_$0': 'MyClass'});

      await dir.delete(recursive: true);
    });
  });
}
