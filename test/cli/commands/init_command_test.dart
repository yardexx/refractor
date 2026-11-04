import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:refractor/src/cli/commands/init_command.dart';
import 'package:test/test.dart';

import '../../helpers/cwd_test_lock.dart';

void main() {
  group('InitCommand', () {
    late CwdTestLock cwdLock;
    late Directory tempDir;
    late _MockLogger logger;
    late CommandRunner<int> runner;

    setUp(() async {
      cwdLock = await CwdTestLock.acquire();
      tempDir = await Directory.systemTemp.createTemp('refractor_init_test_');
      Directory.current = tempDir.path;

      logger = _MockLogger();
      runner = CommandRunner<int>('test', 'test')
        ..addCommand(InitCommand(logger: logger));
    });

    tearDown(() async {
      Directory.current = Directory.systemTemp.path;
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
      await cwdLock.release();
    });

    test('creates default refractor.yaml when file does not exist', () async {
      final exitCode = await runner.run(['init']);
      final file = File('refractor.yaml');
      final yaml = file.readAsStringSync();

      expect(exitCode, ExitCode.success.code);
      expect(file.existsSync(), isTrue);
      expect(yaml, contains('refractor:'));
      expect(yaml, contains('  # exclude:'));
      expect(yaml, contains('  passes:'));
      expect(yaml, isNot(contains('preserve_main')));
      expect(yaml, isNot(contains('\nexclude:')));
      expect(yaml, isNot(contains('\nverbose:')));
      expect(yaml, isNot(contains('symbol_map')));
    });

    test(
      'does not overwrite existing file when confirm returns false',
      () async {
        final file = File('refractor.yaml')
          ..writeAsStringSync('custom: keep\n');
        when(() => logger.confirm(any())).thenReturn(false);

        final exitCode = await runner.run(['init']);

        expect(exitCode, ExitCode.success.code);
        expect(file.readAsStringSync(), 'custom: keep\n');
      },
    );

    test('overwrites existing file when confirm returns true', () async {
      final file = File('refractor.yaml')
        ..writeAsStringSync('custom: replace\n');
      when(() => logger.confirm(any())).thenReturn(true);

      final exitCode = await runner.run(['init']);

      expect(exitCode, ExitCode.success.code);
      expect(file.readAsStringSync(), contains('Refractor configuration'));
      expect(file.readAsStringSync(), isNot('custom: replace\n'));
    });
  });
}

class _MockLogger extends Mock implements Logger {}
