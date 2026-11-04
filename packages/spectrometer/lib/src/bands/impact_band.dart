import 'dart:io';

import 'package:refractor/refractor.dart';
import 'package:spectrometer/src/bands/band.dart';
import 'package:spectrometer/src/fixture_build.dart';
import 'package:spectrometer/src/spectrum.dart';

/// Measures the *cost* of obfuscation in the final binary.
///
/// For now this band reports numbers rather than enforcing baselines: plain
/// vs obfuscated binary size, the size ratio, and the per-pass metrics the
/// engine already emits. The only optional assertion is an upper bound on the
/// size ratio (`impact.max_size_ratio`). Making the numbers visible first —
/// in failure output and CI summaries — is a deliberate step before turning
/// them into regression baselines, which are brittle across SDK bumps.
class ImpactBand implements Band {
  const ImpactBand();

  @override
  String get name => 'impact';

  @override
  Future<BandResult> analyze(FixtureBuild build) async {
    final failures = <String>[];
    final readings = <Reading>[];
    final expectations = build.fixture.expectations;

    final plainSize = _size(build.plain(Target.exe));
    final obfuscated = await build.obfuscated(Target.exe);
    final obfSize = _size(obfuscated.outputPath);
    final ratio = plainSize == 0 ? 0.0 : obfSize / plainSize;

    readings
      ..add(Reading('plain size', _kb(plainSize)))
      ..add(Reading('obfuscated size', _kb(obfSize)))
      ..add(Reading('size ratio', ratio.toStringAsFixed(3)));

    for (final report in obfuscated.result.reports) {
      for (final entry in report.metadata.entries) {
        readings.add(
          Reading('${report.passName}.${entry.key}', entry.value),
        );
      }
    }

    final limit = expectations.maxSizeRatio;
    if (limit != null && ratio > limit) {
      failures.add(
        'size ratio ${ratio.toStringAsFixed(3)} exceeds max $limit',
      );
    }

    return failures.isEmpty
        ? BandResult.passed(name, readings: readings)
        : BandResult.failed(name, failures: failures, readings: readings);
  }

  int _size(String path) => File(path).lengthSync();

  String _kb(int bytes) => '${(bytes / 1024).toStringAsFixed(1)} KiB';
}
