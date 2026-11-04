/// The outcome of evaluating a single band against a fixture.
enum BandStatus {
  /// The band ran and every assertion held.
  pass,

  /// The band ran and at least one assertion failed.
  fail,

  /// The band could not run (e.g. a required tool was unavailable).
  skipped,
}

/// A single named measurement produced while evaluating a band.
///
/// Readings are diagnostics, not pass/fail signals. They exist so that a
/// build's numbers (binary sizes, rename counts, encrypted-string counts)
/// are always visible — in failure messages and in CI summaries — even when
/// no assertion references them yet.
class Reading {
  const Reading(this.label, this.value);

  final String label;
  final String value;

  @override
  String toString() => '$label: $value';
}

/// The result of one band (correctness / resistance / impact) for a fixture.
class BandResult {
  BandResult({
    required this.band,
    required this.status,
    this.failures = const [],
    this.readings = const [],
  });

  /// A band that ran cleanly with the given [readings].
  BandResult.passed(String band, {List<Reading> readings = const []})
    : this(band: band, status: BandStatus.pass, readings: readings);

  /// A band that ran but failed with one or more [failures].
  BandResult.failed(
    String band, {
    required List<String> failures,
    List<Reading> readings = const [],
  }) : this(
         band: band,
         status: BandStatus.fail,
         failures: failures,
         readings: readings,
       );

  /// A band that could not run, with a human reason in [failures].
  BandResult.skip(String band, String reason)
    : this(band: band, status: BandStatus.skipped, failures: [reason]);

  final String band;
  final BandStatus status;
  final List<String> failures;
  final List<Reading> readings;

  bool get isFailure => status == BandStatus.fail;
}

/// The full set of band readings for a single fixture build.
///
/// Named for the optics metaphor: a prism splits one build into a spectrum of
/// independently measurable bands.
class Spectrum {
  Spectrum({required this.fixture, required this.bands});

  final String fixture;
  final List<BandResult> bands;

  /// `true` when no band failed. Skipped bands do not fail the spectrum —
  /// callers that treat a skip as a hard error (e.g. CI) should inspect
  /// [skipped] explicitly.
  bool get ok => bands.every((b) => b.status != BandStatus.fail);

  Iterable<BandResult> get skipped =>
      bands.where((b) => b.status == BandStatus.skipped);

  /// A multi-line, human-readable rendering suitable for a test failure
  /// message or a CI step summary.
  String describe() {
    final buffer = StringBuffer('Spectrum for "$fixture":\n');
    for (final band in bands) {
      buffer.writeln('  [${_glyph(band.status)}] ${band.band}');
      for (final reading in band.readings) {
        buffer.writeln('      • $reading');
      }
      for (final failure in band.failures) {
        buffer.writeln('      ✗ $failure');
      }
    }
    return buffer.toString();
  }

  static String _glyph(BandStatus status) => switch (status) {
    BandStatus.pass => 'PASS',
    BandStatus.fail => 'FAIL',
    BandStatus.skipped => 'SKIP',
  };
}
