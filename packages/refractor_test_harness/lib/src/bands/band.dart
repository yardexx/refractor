import 'package:refractor_test_harness/src/fixture_build.dart';
import 'package:refractor_test_harness/src/spectrum.dart';

/// One axis of analysis applied to a fixture build.
///
/// Bands are independent: each reads whatever it needs from the shared
/// [FixtureBuild] (building lazily and sharing results) and returns a
/// structured [BandResult]. A band never throws for an expected failure —
/// it returns [BandStatus.fail] with reasons so the whole spectrum is always
/// reported, not just the first problem.
abstract interface class Band {
  String get name;

  Future<BandResult> analyze(FixtureBuild build);
}
