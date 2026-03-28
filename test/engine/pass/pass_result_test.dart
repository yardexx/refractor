import 'package:refractor/src/engine/pass.dart';
import 'package:test/test.dart';

void main() {
  group('PassResult', () {
    test('success can carry an artifact', () {
      const artifact = _FakeArtifact('rename');
      const result = PassSucceeded(
        artifact: artifact,
        report: PassReport(passName: 'rename'),
      );

      expect(result.artifact, same(artifact));
      expect(result.report.passName, 'rename');
    });

    test('success can omit an artifact', () {
      const result = PassSucceeded(
        report: PassReport(passName: 'string_encrypt'),
      );

      expect(result, isA<PassSucceeded>());
      expect(result.artifact, isNull);
      expect(result.report.passName, 'string_encrypt');
    });

    test('failure carries error and report', () {
      final error = Exception('boom');
      final result = PassFailed(
        error: error,
        report: const PassReport(
          passName: 'string_encrypt',
          message: 'boom',
        ),
      );

      expect(result.error, same(error));
      expect(result.report.message, 'boom');
    });
  });
}

final class _FakeArtifact extends PassArtifact {
  const _FakeArtifact(this.value);

  final String value;

  @override
  Map<String, Object?> toJson() => {'value': value};
}
