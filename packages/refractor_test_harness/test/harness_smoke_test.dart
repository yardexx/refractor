@TestOn('vm')
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:refractor_test_harness/refractor_test_harness.dart';
import 'package:test/test.dart';

void main() {
  test('sample fixture passes every band', () async {
    final fixtureDir = p.join(await _packageRoot(), 'test/fixtures/sample');

    final spectrum = await const Harness().analyzeDir(fixtureDir);

    // Always print the readings so the numbers (sizes, counts) are visible
    // in CI output even on a green run.
    printOnFailure(spectrum.describe());

    expect(spectrum.ok, isTrue, reason: spectrum.describe());

    // Correctness and impact are not tool-gated and must run.
    for (final band in ['correctness', 'impact']) {
      final result = spectrum.bands.singleWhere((b) => b.band == band);
      expect(
        result.status,
        BandStatus.pass,
        reason: 'band "$band" did not pass:\n${spectrum.describe()}',
      );
    }
  });
}

Future<String> _packageRoot() async {
  final uri = await Isolate.resolvePackageUri(
    Uri.parse('package:refractor_test_harness/refractor_test_harness.dart'),
  );
  if (uri == null || uri.scheme != 'file') {
    throw StateError('cannot resolve package:refractor_test_harness');
  }
  return p.normalize(p.join(p.dirname(File.fromUri(uri).path), '..'));
}
