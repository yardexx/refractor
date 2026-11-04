import 'dart:io';

import 'package:spectrometer/src/bands/band.dart';
import 'package:spectrometer/src/bands/correctness_band.dart';
import 'package:spectrometer/src/bands/impact_band.dart';
import 'package:spectrometer/src/bands/resistance_band.dart';
import 'package:spectrometer/src/fixture.dart';
import 'package:spectrometer/src/fixture_build.dart';
import 'package:spectrometer/src/spectrum.dart';

/// Entry point: builds a fixture once and measures it across every band,
/// producing a [Spectrum] of readings.
class Spectrometer {
  const Spectrometer({this.bands = defaultBands});

  /// The default band set: correctness, resistance, impact.
  static const List<Band> defaultBands = [
    CorrectnessBand(),
    ResistanceBand(),
    ImpactBand(),
  ];

  final List<Band> bands;

  /// Loads the fixture at [fixtureDir] and [measure]s it.
  Future<Spectrum> measureDir(String fixtureDir) =>
      measure(Fixture.load(fixtureDir));

  /// Builds [fixture] in a temporary working directory, runs every band
  /// against that shared build, and returns the aggregated [Spectrum]. The
  /// working directory is always cleaned up.
  Future<Spectrum> measure(Fixture fixture) async {
    final workDir = Directory.systemTemp.createTempSync(
      'spectrometer_${fixture.name}_',
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
