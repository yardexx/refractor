/// How much weight to put on a leak.
///
/// Native-binary scanning works on spellings, not scoped identities, so a
/// short or common original (`value`, `name`) can appear for reasons that have
/// nothing to do with the user's code. Those are reported but not fatal;
/// distinctive originals are high-confidence and gate the build.
enum Confidence { high, low }

/// A single original identifier that was found in the artifact even though the
/// symbol map says it was renamed away.
class Leak {
  const Leak({
    required this.original,
    required this.offset,
    required this.confidence,
  });

  final String original;
  final int offset;
  final Confidence confidence;

  Map<String, Object?> toJson() => {
        'original': original,
        'offset': offset,
        'confidence': confidence.name,
      };
}

/// The result of verifying one artifact against one symbol map.
class VerificationReport {
  VerificationReport({
    required this.artifactPath,
    required this.originalsChecked,
    required this.leaks,
    required this.failOn,
  });

  final String artifactPath;
  final int originalsChecked;
  final List<Leak> leaks;
  final Confidence? failOn;

  Iterable<Leak> get highConfidence =>
      leaks.where((l) => l.confidence == Confidence.high);

  Iterable<Leak> get lowConfidence =>
      leaks.where((l) => l.confidence == Confidence.low);

  /// Whether the run should be treated as a failure, per [failOn].
  ///
  /// * `Confidence.high` (default): fail only on high-confidence leaks.
  /// * `Confidence.low`: fail on any leak at all.
  /// * `null`: never fail (report-only).
  bool get passed => switch (failOn) {
        null => true,
        Confidence.high => highConfidence.isEmpty,
        Confidence.low => leaks.isEmpty,
      };

  Map<String, Object?> toJson() => {
        'artifact': artifactPath,
        'originals_checked': originalsChecked,
        'passed': passed,
        'leaks': [for (final leak in leaks) leak.toJson()],
        'summary': {
          'total': leaks.length,
          'high': highConfidence.length,
          'low': lowConfidence.length,
        },
      };

  String describe() {
    final buffer = StringBuffer()
      ..writeln('prism verify: $artifactPath')
      ..writeln('  checked $originalsChecked original identifiers')
      ..writeln(
        '  ${leaks.length} leaked '
        '(${highConfidence.length} high-confidence, '
        '${lowConfidence.length} low-confidence)',
      );
    for (final leak in leaks) {
      final tag = leak.confidence == Confidence.high ? 'HIGH' : 'low ';
      final at = '0x${leak.offset.toRadixString(16)}';
      buffer.writeln('    [$tag] "${leak.original}" at byte $at');
    }
    buffer.writeln(passed ? '  VERDICT: pass' : '  VERDICT: FAIL');
    return buffer.toString();
  }
}
