import 'package:refractor/src/engine/pass.dart';
import 'package:test/test.dart';

void main() {
  group('PassResults', () {
    late PassResults results;

    setUp(() {
      results = PassResults();
    });

    test('addArtifact + artifact round-trips value', () {
      const artifact = _StringArtifact('mapping-data');
      results.addArtifact('rename', artifact);
      expect(results.artifact<_StringArtifact>('rename'), same(artifact));
    });

    test('artifact returns null for missing key', () {
      expect(results.artifact<_StringArtifact>('nonexistent'), isNull);
    });

    test('multiple passes store independently', () {
      results
        ..addArtifact('rename', const _IntArtifact(42))
        ..addArtifact('encrypt', const _StringArtifact('secret'));
      expect(results.artifact<_IntArtifact>('rename')?.value, equals(42));
      expect(
        results.artifact<_StringArtifact>('encrypt')?.value,
        equals('secret'),
      );
    });

    test('later add overwrites earlier value', () {
      results
        ..addArtifact('rename', const _StringArtifact('first'))
        ..addArtifact('rename', const _StringArtifact('second'));
      expect(
        results.artifact<_StringArtifact>('rename')?.value,
        equals('second'),
      );
    });

    test('artifact lookup returns null for wrong type', () {
      results.addArtifact('rename', const _StringArtifact('mapping-data'));

      expect(results.artifact<_IntArtifact>('rename'), isNull);
    });

    test('reports are collected in order', () {
      results
        ..addReport(const PassReport(passName: 'first'))
        ..addReport(const PassReport(passName: 'second'));

      expect(
        results.reports.map((report) => report.passName),
        ['first', 'second'],
      );
    });

    test('failures are collected in order', () {
      results
        ..addFailure(
          PassFailureRecord(passName: 'first', error: Exception('a')),
        )
        ..addFailure(
          PassFailureRecord(passName: 'second', error: Exception('b')),
        );

      expect(
        results.failures.map((failure) => failure.passName),
        ['first', 'second'],
      );
    });

    test('toJson serializes artifacts, reports, failures, and skipped', () {
      results
        ..addArtifact('rename', const _StringArtifact('mapping-data'))
        ..addReport(
          const PassReport(
            passName: 'rename',
            metadata: {'classes': '1'},
          ),
        )
        ..addFailure(
          PassFailureRecord(passName: 'string_encrypt', error: Exception('x')),
        )
        ..addSkipped('literal_encode');

      expect(results.toJson(), {
        'artifacts': {
          'rename': {'value': 'mapping-data'},
        },
        'reports': [
          {
            'pass_name': 'rename',
            'message': null,
            'metadata': {'classes': '1'},
          },
        ],
        'failures': [
          {
            'pass_name': 'string_encrypt',
            'error': 'Exception: x',
          },
        ],
        'skipped': ['literal_encode'],
      });
    });

    test('artifacts exposes collected pass artifacts', () {
      results.addArtifact('rename', const _StringArtifact('mapping-data'));

      expect(results.artifacts, {
        'rename': const _StringArtifact('mapping-data'),
      });
    });
  });
}

final class _StringArtifact extends PassArtifact {
  const _StringArtifact(this.value);

  final String value;

  @override
  Map<String, Object?> toJson() => {'value': value};
}

final class _IntArtifact extends PassArtifact {
  const _IntArtifact(this.value);

  final int value;

  @override
  Map<String, Object?> toJson() => {'value': value};
}
