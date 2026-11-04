@TestOn('vm')
library;

import 'package:prism/prism.dart';
import 'package:test/test.dart';

void main() {
  // A fake artifact view. BinaryScanner takes the decoded (latin1) string
  // directly, so no file is needed.
  final scanner = BinaryScanner(
    'header SecretAlgorithm token=sk_live_ABC123 '
    'VISIBLE_MARKER restart end',
  );

  PolicyReport run(String yaml) =>
      const PolicyChecker().check(scanner: scanner, policy: Policy.parse(yaml));

  test('must_not_contain flags a present forbidden string as an error', () {
    final report = run('''
assertions:
  - must_not_contain: ["SecretAlgorithm"]
''');

    expect(report.assertionsChecked, 1);
    expect(report.errors, hasLength(1));
    expect(report.passed, isFalse);
  });

  test('must_not_contain passes when the string is absent', () {
    final report = run('''
assertions:
  - must_not_contain: ["NotPresentAnywhere"]
''');

    expect(report.violations, isEmpty);
    expect(report.passed, isTrue);
  });

  test('must_contain flags a missing required marker', () {
    final report = run('''
assertions:
  - must_contain: ["VISIBLE_MARKER", "MISSING_MARKER"]
''');

    expect(report.violations, hasLength(1));
    expect(report.violations.single.detail, contains('MISSING_MARKER'));
  });

  test('must_not_match flags a matching pattern', () {
    final report = run('''
assertions:
  - must_not_match: "sk_live_[A-Za-z0-9]+"
''');

    expect(report.errors, hasLength(1));
    expect(report.passed, isFalse);
  });

  test('case_insensitive controls regex matching', () {
    final sensitive = run('''
assertions:
  - must_not_match: "secretalgorithm"
''');
    expect(sensitive.violations, isEmpty, reason: 'case-sensitive by default');

    final insensitive = run('''
assertions:
  - must_not_match: "secretalgorithm"
    case_insensitive: true
''');
    expect(insensitive.violations, hasLength(1));
  });

  test('warn severity records a violation but does not fail', () {
    final report = run('''
assertions:
  - must_not_contain: ["SecretAlgorithm"]
    severity: warn
''');

    expect(report.warnings, hasLength(1));
    expect(report.errors, isEmpty);
    expect(report.passed, isTrue);
  });

  test('raw substring match is not boundary-aware (unlike the map band)', () {
    // "estar" occurs inside "restart"; policy literals are raw substrings.
    final report = run('''
assertions:
  - must_not_contain: ["estar"]
''');

    expect(report.violations, hasLength(1));
  });

  test('rejects an invalid must_not_match regex at parse time', () {
    expect(
      () => Policy.parse('''
assertions:
  - must_not_match: "sk_(["
'''),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('not a valid regex'),
        ),
      ),
    );
  });

  test('rejects an unknown assertion kind', () {
    expect(
      () => Policy.parse('''
assertions:
  - frobnicate: ["x"]
'''),
      throwsFormatException,
    );
  });
}
