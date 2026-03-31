@TestOn('vm')
@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:refractor/src/engine/passes/rename/reporting/rename_artifact.dart';
import 'package:test/test.dart';

import '../helpers/resistance_test_harness.dart';

void main() {
  late Directory tempDir;
  final stringsPath = findStringsExecutable();

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('refractor_resistance_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('Resistance tests', () {
    test('rename fixture does not leak original identifiers', () async {
      if (stringsPath == null) {
        markTestSkipped(
          'Skipping resistance test: `strings` not found on PATH',
        );
        return;
      }

      final fixture = ResistanceFixture.load('rename');
      final run = await buildResistanceFixture(fixture, tempDir);
      final outputFile = File(run.outputPath);

      expect(outputFile.existsSync(), isTrue);
      expect(outputFile.lengthSync(), greaterThan(0));
      expect(run.buildResult.failures, isEmpty);
      expect(run.normalizedStringsOutput, isNotEmpty);
      final renameArtifact = run.buildResult.passResults
          .artifact<RenameArtifact>('rename');

      for (final originalName in fixture.expectations.renameHelpers) {
        expect(
          renameArtifact?.mapping.symbolMap.containsValue(originalName),
          isTrue,
          reason: 'Expected $originalName to be present in the rename map.',
        );
      }

      for (final leakedValue in fixture.expectations.denylist) {
        expect(
          outputContains(run.normalizedStringsOutput, leakedValue),
          isFalse,
          reason: 'Unexpected plaintext leak in strings output: $leakedValue',
        );
      }

      for (final preservedValue in fixture.expectations.allowlist) {
        expect(
          outputContains(run.normalizedStringsOutput, preservedValue),
          isTrue,
          reason:
              'Expected preserved value missing from strings output: '
              '$preservedValue',
        );
      }
    });

    test('string_encrypt fixture protects plaintext strings', () async {
      if (stringsPath == null) {
        markTestSkipped(
          'Skipping resistance test: `strings` not found on PATH',
        );
        return;
      }

      final fixture = ResistanceFixture.load('string_encrypt');
      final run = await buildResistanceFixture(fixture, tempDir);
      final outputFile = File(run.outputPath);

      expect(outputFile.existsSync(), isTrue);
      expect(outputFile.lengthSync(), greaterThan(0));
      expect(run.buildResult.failures, isEmpty);
      expect(run.normalizedStringsOutput, isNotEmpty);

      for (final entry in fixture.expectations.requiredMetrics.entries) {
        expect(
          metricValue(run.buildResult, entry.key),
          greaterThanOrEqualTo(entry.value),
          reason: 'Expected metric ${entry.key} >= ${entry.value}',
        );
      }

      for (final leakedValue in fixture.expectations.denylist) {
        expect(
          outputContains(run.normalizedStringsOutput, leakedValue),
          isFalse,
          reason: 'Unexpected plaintext leak in strings output: $leakedValue',
        );
      }

      for (final preservedValue in fixture.expectations.allowlist) {
        expect(
          outputContains(run.normalizedStringsOutput, preservedValue),
          isTrue,
          reason:
              'Expected preserved value missing from strings output: '
              '$preservedValue',
        );
      }
    });
  });
}
