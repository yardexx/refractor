import 'dart:io';

import 'package:prism/src/bands/band.dart';
import 'package:prism/src/bands/correctness_band.dart';
import 'package:prism/src/bands/impact_band.dart';
import 'package:prism/src/bands/resistance_band.dart';
import 'package:prism/src/fixture.dart';
import 'package:prism/src/fixture_build.dart';
import 'package:prism/src/spectrum.dart';

/// Entry point for prism: splits a fixture build into a [Spectrum] of bands.
class Prism {
  const Prism({this.bands = defaultBands});

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
      'prism_${fixture.name}_',
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
