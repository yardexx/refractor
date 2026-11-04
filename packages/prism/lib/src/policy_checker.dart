import 'package:prism/src/binary_scanner.dart';
import 'package:prism/src/policy.dart';

/// One assertion that did not hold.
class PolicyViolation {
  const PolicyViolation({
    required this.assertion,
    required this.detail,
    required this.severity,
    this.offset,
  });

  final String assertion;
  final String detail;
  final PolicySeverity severity;
  final int? offset;

  Map<String, Object?> toJson() => {
        'assertion': assertion,
        'detail': detail,
        'severity': severity.name,
        if (offset != null) 'offset': offset,
      };
}

/// The result of evaluating a [Policy] against an artifact.
class PolicyReport {
  PolicyReport({
    required this.assertionsChecked,
    required this.violations,
  });

  final int assertionsChecked;
  final List<PolicyViolation> violations;

  Iterable<PolicyViolation> get errors =>
      violations.where((v) => v.severity == PolicySeverity.error);

  Iterable<PolicyViolation> get warnings =>
      violations.where((v) => v.severity == PolicySeverity.warn);

  /// Passes unless an `error`-severity assertion was violated.
  bool get passed => errors.isEmpty;

  Map<String, Object?> toJson() => {
        'assertions_checked': assertionsChecked,
        'passed': passed,
        'violations': [for (final v in violations) v.toJson()],
      };

  String describe() {
    final buffer = StringBuffer()
      ..writeln('policy: $assertionsChecked assertions, '
          '${violations.length} violated '
          '(${errors.length} error, ${warnings.length} warn)');
    for (final v in violations) {
      final tag = v.severity == PolicySeverity.error ? 'ERROR' : 'warn ';
      final at =
          v.offset == null ? '' : ' at byte 0x${v.offset!.toRadixString(16)}';
      buffer.writeln('    [$tag] ${v.assertion}: ${v.detail}$at');
    }
    return buffer.toString();
  }
}

/// Evaluates customer assertions against an artifact's bytes.
class PolicyChecker {
  const PolicyChecker();

  PolicyReport check({
    required BinaryScanner scanner,
    required Policy policy,
  }) {
    final violations = <PolicyViolation>[];

    for (final assertion in policy.assertions) {
      switch (assertion) {
        case MustNotContain(:final needles, :final severity):
          for (final needle in needles) {
            final offset = scanner.indexOfRaw(needle);
            if (offset != null) {
              violations.add(
                PolicyViolation(
                  assertion: assertion.label,
                  detail: 'forbidden string "$needle" present',
                  severity: severity,
                  offset: offset,
                ),
              );
            }
          }
        case MustContain(:final needles, :final severity):
          for (final needle in needles) {
            if (scanner.indexOfRaw(needle) == null) {
              violations.add(
                PolicyViolation(
                  assertion: assertion.label,
                  detail: 'required string "$needle" missing',
                  severity: severity,
                ),
              );
            }
          }
        case MustNotMatch(:final pattern, :final severity):
          final offset = scanner.firstMatch(assertion.regExp);
          if (offset != null) {
            violations.add(
              PolicyViolation(
                assertion: assertion.label,
                detail: 'forbidden pattern /$pattern/ matched',
                severity: severity,
                offset: offset,
              ),
            );
          }
      }
    }

    return PolicyReport(
      assertionsChecked: policy.assertions.length,
      violations: violations,
    );
  }
}
