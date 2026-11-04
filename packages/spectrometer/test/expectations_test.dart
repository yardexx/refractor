import 'package:refractor/refractor.dart';
import 'package:spectrometer/spectrometer.dart';
import 'package:test/test.dart';

void main() {
  test('parses every section', () {
    final e = Expectations.fromYaml('''
behavior:
  targets: [exe, aot]
  equivalent_to_plain: false
  verify_kernel: false
resistance:
  denylist: [Secret]
  allowlist: [MARKER]
  rename_helpers: [Secret]
  required_metrics:
    string_encrypt.strings_encrypted: 2
impact:
  max_size_ratio: 1.5
''');

    expect(e.targets, [Target.exe, Target.aot]);
    expect(e.checkEquivalence, isFalse);
    expect(e.verifyKernel, isFalse);
    expect(e.denylist, ['Secret']);
    expect(e.allowlist, ['MARKER']);
    expect(e.renameHelpers, ['Secret']);
    expect(e.requiredMetrics, {'string_encrypt.strings_encrypted': 2});
    expect(e.maxSizeRatio, 1.5);
  });

  test('every section is optional', () {
    final e = Expectations.fromYaml('behavior: {}');

    expect(e.targets, [Target.exe]);
    expect(e.checkEquivalence, isTrue);
    expect(e.verifyKernel, isTrue);
    expect(e.denylist, isEmpty);
    expect(e.maxSizeRatio, isNull);
  });

  test('rejects an unknown section, such as the old flat schema', () {
    expect(
      () => Expectations.fromYaml('denylist: [Secret]'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('denylist'),
        ),
      ),
    );
  });

  test('rejects a misspelled key inside a section', () {
    expect(
      () => Expectations.fromYaml('resistance:\n  denylsit: [Secret]\n'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('denylsit'),
        ),
      ),
    );
  });
}
