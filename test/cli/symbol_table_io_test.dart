import 'dart:convert';
import 'dart:io';

import 'package:refractor/src/cli/symbol_table_io.dart';
import 'package:refractor/src/engine/symbol_table.dart';
import 'package:test/test.dart';

void main() {
  group('SymbolTableIo', () {
    test('writes symbol map to disk', () async {
      final table = SymbolTable()..record('MyClass', r'_$0');
      final dir = await Directory.systemTemp.createTemp('symbol_table_test_');
      final file = File('${dir.path}/maps/symbols.json');

      table.writeToPath(file.path);

      expect(file.existsSync(), isTrue);
      final decoded =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(decoded, {r'_$0': 'MyClass'});

      await dir.delete(recursive: true);
    });
  });
}
