@TestOn('vm')
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:spectrometer/spectrometer.dart';
import 'package:test/test.dart';

/// Measures every fixture under `test/fixtures/`. Adding a fixture is just
/// adding a directory: no test code to write.
void main() {
  final fixturesDir = Directory(p.join(_packageRoot(), 'test', 'fixtures'));
  final fixtures = fixturesDir.listSync().whereType<Directory>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('fixtures are discovered', () {
    expect(fixtures, isNotEmpty);
  });

  for (final dir in fixtures) {
    final name = p.basename(dir.path);
    test('fixture "$name" passes every band', () async {
      final spectrum = await const Spectrometer().measureDir(dir.path);

      // Readings (sizes, counts) are printed whenever the test fails.
      printOnFailure(spectrum.describe());
      expect(spectrum.ok, isTrue, reason: spectrum.describe());

      // No band depends on an external tool, so every band must actually
      // run: a skip would hide a gap, not just a missing tool.
      for (final band in spectrum.bands) {
        expect(
          band.status,
          BandStatus.pass,
          reason: 'band "${band.band}" did not pass:\n${spectrum.describe()}',
        );
      }
    });
  }
}

String _packageRoot() {
  final uri = Isolate.resolvePackageUriSync(
    Uri.parse('package:spectrometer/spectrometer.dart'),
  );
  if (uri == null || uri.scheme != 'file') {
    throw StateError('cannot resolve package:spectrometer');
  }
  return p.normalize(p.join(p.dirname(p.fromUri(uri)), '..'));
}
