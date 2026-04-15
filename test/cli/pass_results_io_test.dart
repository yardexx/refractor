import 'dart:convert';
import 'dart:io';

import 'package:refractor/src/cli/pass_results_io.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:test/test.dart';

void main() {
  group('PassResultsIo', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'refractor_pass_results_io_',
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('hasArtifacts is false for empty results', () {
      expect(PassResults().hasArtifacts, isFalse);
    });

    test('serializes combined artifact json shape', () {
      final results = PassResults()
        ..addArtifact('rename', const _JsonArtifact({'symbol_map': {}}))
        ..addArtifact('string_encrypt', const _JsonArtifact({'records': []}));

      expect(results.hasArtifacts, isTrue);
      expect(results.toArtifactsJson(), {
        'passes': {
          'rename': {'symbol_map': <String, Object?>{}},
          'string_encrypt': {'records': <Object?>[]},
        },
      });
    });

    test('writes indented artifact json and creates parent directories', () {
      final results = PassResults()
        ..addArtifact(
          'rename',
          const _JsonArtifact({
            'symbol_map': {'a': 'b'},
          }),
        );
      final output = File(
        '${tempDir.path}${Platform.pathSeparator}reports'
        '${Platform.pathSeparator}artifacts.json',
      );

      results.writeArtifactsToPath(output.path);

      expect(output.existsSync(), isTrue);
      expect(output.readAsStringSync(), contains('\n  "passes": {\n'));
      expect(jsonDecode(output.readAsStringSync()), {
        'passes': {
          'rename': {
            'symbol_map': {'a': 'b'},
          },
        },
      });
    });
  });
}

final class _JsonArtifact extends PassArtifact {
  const _JsonArtifact(this.value);

  final Map<String, Object?> value;

  @override
  Map<String, Object?> toJson() => value;
}
