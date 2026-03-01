import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:refractor/src/cli/command_runner.dart';
import 'package:test/test.dart';

void main() {
  group('RefractorCommandRunner', () {
    late _MockLogger logger;

    setUp(() {
      logger = _MockLogger();
      when(() => logger.err(any())).thenReturn(null);
      when(() => logger.info(any())).thenReturn(null);
      when(() => logger.detail(any())).thenReturn(null);
    });

    test('returns usage exit code for unknown command', () async {
      final runner = RefractorCommandRunner(logger: logger);

      final exitCode = await runner.run(['unknown']);

      expect(exitCode, ExitCode.usage.code);
    });

    test('returns config exit code when build config is missing', () async {
      final originalCurrentDir = Directory.current.path;
      final tempDir = await Directory.systemTemp.createTemp(
        'refractor_runner_',
      );

      try {
        Directory.current = tempDir.path;
        final runner = RefractorCommandRunner(logger: logger);

        final exitCode = await runner.run(['build']);

        expect(exitCode, ExitCode.config.code);
      } finally {
        Directory.current = originalCurrentDir;
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}

class _MockLogger extends Mock implements Logger {}
