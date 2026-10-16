import 'dart:convert';

import 'package:refractor/src/exceptions/refractor_exception.dart';
import 'package:refractor/src/symbolication/symbol_map.dart';
import 'package:test/test.dart';

void main() {
  group('SymbolMap', () {
    test('toJson carries version, kind, and symbols', () {
      const map = SymbolMap(symbols: {'a': 'Original', 'lib::b': 'other'});
      expect(map.toJson(), {
        'version': currentSymbolMapVersion,
        'kind': symbolMapKind,
        'symbols': {'a': 'Original', 'lib::b': 'other'},
      });
    });

    test('round-trips through JSON', () {
      const map = SymbolMap(symbols: {'a': 'Original', 'c': 'Another'});
      final decoded = SymbolMap.fromJson(
        jsonDecode(map.toJsonString()) as Map<String, dynamic>,
      );
      expect(decoded.version, currentSymbolMapVersion);
      expect(decoded.symbols, {'a': 'Original', 'c': 'Another'});
    });

    test('originalFor resolves a key or returns null', () {
      const map = SymbolMap(symbols: {'a': 'Original'});
      expect(map.originalFor('a'), 'Original');
      expect(map.originalFor('missing'), isNull);
    });

    test('fromJson rejects a document without the refractor marker', () {
      expect(
        () => SymbolMap.fromJson({
          'version': 1,
          'symbols': <String, dynamic>{},
        }),
        throwsA(isA<ConfigException>()),
      );
    });

    test('fromJson rejects a non-integer version', () {
      expect(
        () => SymbolMap.fromJson({
          'version': 'one',
          'kind': symbolMapKind,
          'symbols': <String, dynamic>{},
        }),
        throwsA(isA<ConfigException>()),
      );
    });

    test('fromJson accepts a newer version best-effort', () {
      final map = SymbolMap.fromJson({
        'version': currentSymbolMapVersion + 1,
        'kind': symbolMapKind,
        'symbols': {'a': 'Original'},
      });
      expect(map.version, currentSymbolMapVersion + 1);
      expect(map.originalFor('a'), 'Original');
    });
  });
}
