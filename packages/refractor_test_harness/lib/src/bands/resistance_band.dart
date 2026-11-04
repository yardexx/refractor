import 'package:prism/prism.dart' show BinaryScanner;
import 'package:refractor/refractor.dart';
import 'package:refractor_test_harness/src/bands/band.dart';
import 'package:refractor_test_harness/src/fixture_build.dart';
import 'package:refractor_test_harness/src/spectrum.dart';

/// Checks that obfuscation *actually happened* in the shipped artifact:
/// forbidden plaintext is gone, deliberately preserved markers remain, and
/// pass metrics clear their minimums.
///
/// Scans the native executable's raw bytes with prism's [BinaryScanner], the
/// same scanner the customer-facing verifier uses. Denylist and allowlist
/// entries are raw substrings: a forbidden string is flagged wherever it
/// appears, with no minimum run length and no dependency on an external
/// `strings` tool, so the band always runs on every platform.
class ResistanceBand implements Band {
  const ResistanceBand();

  @override
  String get name => 'resistance';

  @override
  Future<BandResult> analyze(FixtureBuild build) async {
    final expectations = build.fixture.expectations;
    final failures = <String>[];
    final readings = <Reading>[];

    final obfuscated = await build.obfuscated(Target.exe);
    final scanner = BinaryScanner.ofFile(obfuscated.outputPath);
    readings.add(Reading('bytes scanned', '${scanner.byteLength}'));

    for (final needle in expectations.denylist) {
      final offset = scanner.indexOfRaw(needle);
      if (offset != null) {
        failures.add(
          'plaintext leak: "$needle" found in binary '
          'at byte 0x${offset.toRadixString(16)}',
        );
      }
    }
    for (final needle in expectations.allowlist) {
      if (scanner.indexOfRaw(needle) == null) {
        failures.add('expected marker missing: "$needle"');
      }
    }
    for (final entry in expectations.requiredMetrics.entries) {
      final actual = _metric(obfuscated.result, entry.key);
      readings.add(Reading(entry.key, '$actual'));
      if (actual < entry.value) {
        failures.add('metric ${entry.key}=$actual < ${entry.value}');
      }
    }

    return failures.isEmpty
        ? BandResult.passed(name, readings: readings)
        : BandResult.failed(name, failures: failures, readings: readings);
  }

  int _metric(BuildResult result, String key) {
    final parts = key.split('.');
    if (parts.length != 2) {
      throw FormatException('metric must be "<pass>.<metric>": $key');
    }
    for (final report in result.reports.where((r) => r.passName == parts[0])) {
      final value = report.metadata[parts[1]];
      if (value != null) return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}
