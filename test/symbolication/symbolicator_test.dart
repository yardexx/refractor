import 'package:refractor/src/symbolication/symbol_map.dart';
import 'package:refractor/src/symbolication/symbolicator.dart';
import 'package:test/test.dart';

void main() {
  group('Symbolicator', () {
    Symbolicator withSymbols(Map<String, String> symbols) =>
        Symbolicator(SymbolMap(symbols: symbols));

    test('reverses class and member identifiers in a frame', () {
      final sym = withSymbols({'a': 'Secret', 'b': 'value'});
      expect(
        sym.symbolicateLine('#0      a.b (package:app/x.dart:3:5)'),
        '#0      Secret.value (package:app/x.dart:3:5)',
      );
    });

    test('reverses a top-level function frame', () {
      final sym = withSymbols({'c': 'compute'});
      expect(
        sym.symbolicateLine('#1      c (package:app/x.dart:9:1)'),
        '#1      compute (package:app/x.dart:9:1)',
      );
    });

    test('never rewrites identifiers inside the file location', () {
      // `foo` is a mapped symbol AND appears in the file path; only the symbol
      // part must change.
      final sym = withSymbols({'foo': 'Bar'});
      expect(
        sym.symbolicateLine('#0      foo (package:app/foo.dart:1:1)'),
        '#0      Bar (package:app/foo.dart:1:1)',
      );
    });

    test('leaves unmapped tokens untouched', () {
      final sym = withSymbols({'a': 'Secret'});
      expect(
        sym.symbolicateLine('#0      a.unknown (package:app/x.dart:1:1)'),
        '#0      Secret.unknown (package:app/x.dart:1:1)',
      );
    });

    test('passes non-frame lines through unchanged', () {
      final sym = withSymbols({'a': 'Secret'});
      expect(
        sym.symbolicateLine('Unhandled exception: a failed'),
        'Unhandled exception: a failed',
      );
    });

    test('symbolicates a multi-line trace', () {
      final sym = withSymbols({'a': 'Secret', 'b': 'value', 'c': 'helper'});
      const trace =
          'Unhandled exception: Boom\n'
          '#0      a.b (package:app/x.dart:3:5)\n'
          '#1      c (package:app/x.dart:9:1)\n'
          '#2      main (package:app/x.dart:1:1)';
      expect(
        sym.symbolicateTrace(trace),
        'Unhandled exception: Boom\n'
        '#0      Secret.value (package:app/x.dart:3:5)\n'
        '#1      helper (package:app/x.dart:9:1)\n'
        '#2      main (package:app/x.dart:1:1)',
      );
    });
  });
}
