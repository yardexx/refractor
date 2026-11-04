import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:refractor/refractor.dart';
import 'package:refractor_test_harness/src/bands/band.dart';
import 'package:refractor_test_harness/src/fixture_build.dart';
import 'package:refractor_test_harness/src/spectrum.dart';

/// Checks that obfuscation *actually happened* in the shipped artifact:
/// forbidden plaintext is gone, deliberately preserved markers remain, and
/// pass metrics clear their minimums.
///
/// Uses `strings` on the native executable. When `strings` is unavailable the
/// band reports [BandStatus.skipped]; a CI policy that treats resistance as
/// mandatory should fail on a skip rather than ignore it.
class ResistanceBand implements Band {
  const ResistanceBand();

  @override
  String get name => 'resistance';

  @override
  Future<BandResult> analyze(FixtureBuild build) async {
    final strings = _findStrings();
    if (strings == null) {
      return BandResult.skip(name, '`strings` not found on PATH');
    }

    final expectations = build.fixture.expectations;
    final failures = <String>[];
    final readings = <Reading>[];

    final obfuscated = await build.obfuscated(Target.exe);
    final lines = _stringsOf(strings, obfuscated.outputPath);
    readings.add(Reading('strings lines', '${lines.length}'));

    for (final needle in expectations.denylist) {
      if (lines.any((l) => l.contains(needle))) {
        failures.add('plaintext leak: "$needle" found in binary');
      }
    }
    for (final needle in expectations.allowlist) {
      if (!lines.any((l) => l.contains(needle))) {
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

  List<String> _stringsOf(String strings, String binary) {
    final result = Process.runSync(strings, [binary]);
    if (result.exitCode != 0) {
      throw ProcessException(strings, [binary], '${result.stderr}');
    }
    return (result.stdout as String)
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList(growable: false);
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

  String? _findStrings() {
    final path = Platform.environment['PATH'];
    if (path == null || path.isEmpty) return null;
    final sep = Platform.isWindows ? ';' : ':';
    for (final entry in path.split(sep)) {
      if (entry.isEmpty) continue;
      final candidate = File(p.join(entry, 'strings'));
      if (candidate.existsSync()) return candidate.path;
    }
    return null;
  }
}
