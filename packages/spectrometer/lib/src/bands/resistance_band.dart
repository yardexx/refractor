import 'package:refractor/refractor.dart';
import 'package:refractor/testing.dart';
import 'package:spectrometer/src/bands/band.dart';
import 'package:spectrometer/src/byte_scanner.dart';
import 'package:spectrometer/src/fixture_build.dart';
import 'package:spectrometer/src/spectrum.dart';

/// Checks that obfuscation *actually happened* in the shipped artifact:
/// forbidden plaintext is gone, deliberately preserved markers remain, the
/// rename map covers the identifiers it should, and pass metrics clear their
/// minimums.
///
/// The artifact scan is the primary signal; the rename map and metrics are
/// sanity checks on the engine's own account of what it did. Every denylist
/// entry must also appear in the plain baseline build: one the compiler drops
/// on its own proves nothing, and fails the band as a broken fixture.
/// Denylist and
/// allowlist entries are raw substrings of the native executable's bytes
/// (see [ByteScanner]), so the band needs no external tool and always runs.
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
    final scanner = ByteScanner.ofFile(obfuscated.outputPath);
    readings.add(Reading('bytes scanned', '${scanner.byteLength}'));

    final absent = <String>[];
    for (final needle in expectations.denylist) {
      final offset = scanner.indexOf(needle);
      if (offset != null) {
        failures.add(
          'plaintext leak: "$needle" found in binary '
          'at byte 0x${offset.toRadixString(16)}',
        );
      } else {
        absent.add(needle);
      }
    }

    // Control check: a denylist entry that a plain build doesn't contain
    // either proves nothing — the compiler dropped it, not the obfuscator.
    // That is a broken fixture, so it fails the band rather than passing
    // vacuously.
    if (absent.isNotEmpty) {
      final plain = ByteScanner.ofFile(build.plain(Target.exe));
      final vacuous = [
        for (final needle in absent)
          if (plain.indexOf(needle) == null) needle,
      ];
      readings.add(
        Reading(
          'denylist proven',
          '${absent.length - vacuous.length}/${expectations.denylist.length}',
        ),
      );
      for (final needle in vacuous) {
        failures.add(
          'vacuous denylist entry: "$needle" is absent even from a plain '
          'build, so its absence proves nothing; keep it alive in the fixture '
          "(e.g. @pragma('vm:never-inline')) or drop it",
        );
      }
    }
    for (final needle in expectations.allowlist) {
      if (scanner.indexOf(needle) == null) {
        failures.add('expected marker missing: "$needle"');
      }
    }

    if (expectations.renameHelpers.isNotEmpty) {
      final renamed =
          obfuscated.result.passResults
              .artifact<RenameArtifact>('rename')
              ?.mapping
              .symbolMap
              .values
              .toSet() ??
          const <String>{};
      readings.add(Reading('rename map entries', '${renamed.length}'));
      for (final original in expectations.renameHelpers) {
        if (!renamed.contains(original)) {
          failures.add('rename map has no entry for "$original"');
        }
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
