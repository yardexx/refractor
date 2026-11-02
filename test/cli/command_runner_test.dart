import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:refractor/src/cli/command_runner.dart';
import 'package:test/test.dart';

import '../helpers/cwd_test_lock.dart';

void main() {
  group('RefractorCommandRunner', () {
    late CwdTestLock cwdLock;
    late _MockLogger logger;

    setUp(() async {
      cwdLock = await CwdTestLock.acquire();
      logger = _MockLogger();
      when(() => logger.err(any())).thenReturn(null);
      when(() => logger.info(any())).thenReturn(null);
      when(() => logger.detail(any())).thenReturn(null);
    });

    tearDown(() async {
      Directory.current = Directory.systemTemp.path;
      await cwdLock.release();
    });

    test('returns usage exit code for unknown command', () async {
      final runner = RefractorCommandRunner(logger: logger);

      final exitCode = runner.run(['unknown']);

      expect(exitCode, ExitCode.usage.code);
    });

    test('raises logger level to verbose when --verbose is passed', () async {
      final runner = RefractorCommandRunner(logger: logger);

      runner.run(['--verbose']);

      verify(() => logger.level = Level.verbose).called(1);
    });

    test('returns config exit code when build config is missing', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'refractor_runner_',
      );

      try {
        Directory.current = tempDir.path;
        final runner = RefractorCommandRunner(logger: logger);

        final exitCode = runner.run(['build']);

        expect(exitCode, ExitCode.config.code);
      } finally {
        Directory.current = Directory.systemTemp.path;
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}

class _MockLogger extends Mock implements Logger {}
