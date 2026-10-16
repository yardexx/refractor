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

    test('disambiguates a colliding private member by frame library', () {
      // The same obfuscated `_a` means two different originals in two
      // libraries; only scoped entries exist (no bare `_a`).
      final sym = withSymbols({
        'package:app/foo.dart::_a': '_secret',
        'package:app/bar.dart::_a': '_other',
        'A': 'Foo',
        'B': 'Bar',
      });
      expect(
        sym.symbolicateLine('#0      A._a (package:app/foo.dart:3:5)'),
        '#0      Foo._secret (package:app/foo.dart:3:5)',
      );
      expect(
        sym.symbolicateLine('#1      B._a (package:app/bar.dart:7:1)'),
        '#1      Bar._other (package:app/bar.dart:7:1)',
      );
    });

    test('a scoped entry takes precedence over a bare one', () {
      final sym = withSymbols({
        '_a': '_bareFallback',
        'package:app/foo.dart::_a': '_scoped',
      });
      expect(
        sym.symbolicateLine('#0      C._a (package:app/foo.dart:1:1)'),
        '#0      C._scoped (package:app/foo.dart:1:1)',
      );
    });

    test('falls back to the bare key when no scoped entry matches', () {
      final sym = withSymbols({
        '_a': '_bareFallback',
        'package:app/foo.dart::_a': '_scoped',
      });
      // A frame in a different library has no scoped entry -> bare fallback.
      expect(
        sym.symbolicateLine('#0      C._a (package:app/other.dart:1:1)'),
        '#0      C._bareFallback (package:app/other.dart:1:1)',
      );
    });

    test('handles a location with no column', () {
      final sym = withSymbols({'package:app/foo.dart::_a': '_secret'});
      expect(
        sym.symbolicateLine('#0      X._a (package:app/foo.dart:9)'),
        '#0      X._secret (package:app/foo.dart:9)',
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
