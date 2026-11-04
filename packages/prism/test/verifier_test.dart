@TestOn('vm')
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:prism/prism.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String artifactPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('prism_verify_');
    artifactPath = p.join(tempDir.path, 'app.bin');
    // A fake "binary": distinctive originals present, a common name present,
    // and a token that only occurs as a substring (to prove
    // boundary-awareness). Obfuscated keys are irrelevant — the verifier reads
    // only the map's values — so they are omitted here.
    File(artifactPath).writeAsStringSync(
      'noise\x00 SecretAlgorithm \x00 computeProfitMargin '
      'value \x00 restart end\x00',
    );
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  List<String> leaked(Iterable<Leak> leaks) =>
      leaks.map((l) => l.original).toList();

  test('flags distinctive originals that leaked, as high-confidence', () {
    final report = const Verifier().verify(
      artifactPath: artifactPath,
      symbolMap: SymbolMap({
        'a': 'SecretAlgorithm',
        'b': 'computeProfitMargin',
      }),
    );

    expect(report.originalsChecked, 2);
    expect(
      leaked(report.highConfidence),
      containsAll(['SecretAlgorithm', 'computeProfitMargin']),
    );
    expect(report.passed, isFalse);
  });

  test('does not flag a name that was actually renamed away', () {
    final report = const Verifier().verify(
      artifactPath: artifactPath,
      symbolMap: SymbolMap({'a': 'GoneClass'}),
    );

    expect(report.leaks, isEmpty);
    expect(report.passed, isTrue);
  });

  test('common short names are low-confidence and do not fail by default', () {
    final report = const Verifier().verify(
      artifactPath: artifactPath,
      symbolMap: SymbolMap({'a': 'value'}),
    );

    expect(leaked(report.lowConfidence), ['value']);
    expect(report.highConfidence, isEmpty);
    expect(report.passed, isTrue, reason: 'default fail-on=high');
  });

  test('boundary-aware: "start" inside "restart" is not a match', () {
    final report = const Verifier().verify(
      artifactPath: artifactPath,
      symbolMap: SymbolMap({'a': 'start'}),
    );

    expect(report.leaks, isEmpty);
  });

  test('fail-on=any treats a low-confidence leak as a failure', () {
    final report = const Verifier(failOn: Confidence.low).verify(
      artifactPath: artifactPath,
      symbolMap: SymbolMap({'a': 'value'}),
    );

    expect(report.passed, isFalse);
  });

  test('fail-on=none is report-only', () {
    final report = const Verifier(failOn: null).verify(
      artifactPath: artifactPath,
      symbolMap: SymbolMap({'a': 'SecretAlgorithm'}),
    );

    expect(report.highConfidence, isNotEmpty);
    expect(report.passed, isTrue);
  });

  test('synthetic / non-identifier originals are ignored', () {
    final report = const Verifier().verify(
      artifactPath: artifactPath,
      symbolMap: SymbolMap({
        'a': '_Application&Object&Lifecycle',
        'b': '',
      }),
    );

    expect(report.originalsChecked, 0);
    expect(report.leaks, isEmpty);
  });
}
