import 'dart:io';

import 'package:refractor_test_harness/src/bands/band.dart';
import 'package:refractor_test_harness/src/bands/correctness_band.dart';
import 'package:refractor_test_harness/src/bands/impact_band.dart';
import 'package:refractor_test_harness/src/bands/resistance_band.dart';
import 'package:refractor_test_harness/src/fixture.dart';
import 'package:refractor_test_harness/src/fixture_build.dart';
import 'package:refractor_test_harness/src/spectrum.dart';

/// Entry point for the harness: splits a build into a [Spectrum] of bands.
class Harness {
  const Harness({this.bands = defaultBands});

  /// The default band set: correctness, resistance, impact.
  static const List<Band> defaultBands = [
    CorrectnessBand(),
    ResistanceBand(),
    ImpactBand(),
  ];

  final List<Band> bands;

  /// Loads the fixture at [fixtureDir], builds it once in a temporary working
  /// directory, runs every band against that shared build, and returns the
  /// aggregated [Spectrum]. The working directory is always cleaned up.
  Future<Spectrum> analyzeDir(String fixtureDir) =>
      analyze(Fixture.load(fixtureDir));

  Future<Spectrum> analyze(Fixture fixture) async {
    final workDir = Directory.systemTemp.createTempSync(
      'harness_${fixture.name}_',
    );
    try {
      final build = FixtureBuild(fixture, workDir);
      final results = <BandResult>[];
      for (final band in bands) {
        results.add(await band.analyze(build));
      }
      return Spectrum(fixture: fixture.name, bands: results);
    } finally {
      workDir.deleteSync(recursive: true);
    }
  }
}
