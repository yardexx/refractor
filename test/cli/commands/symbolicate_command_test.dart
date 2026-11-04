import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:refractor/src/cli/commands/symbolicate_command.dart';
import 'package:refractor/src/exceptions/refractor_exception.dart';
import 'package:test/test.dart';

import '../../helpers/cwd_test_lock.dart';

void main() {
  group('SymbolicateCommand', () {
    late CwdTestLock cwdLock;
    late Directory tempDir;
    late CommandRunner<int> runner;
    late _MockLogger logger;

    const mapJson =
        '{"version":1,"kind":"refractor-symbol-map",'
        '"symbols":{"a":"Secret","b":"value"}}';
    const trace =
        '#0      a.b (package:app/x.dart:3:5)\n'
        '#1      main (package:app/x.dart:1:1)';

    setUp(() async {
      cwdLock = await CwdTestLock.acquire();
      tempDir = await Directory.systemTemp.createTemp('refractor_sym_test_');
      Directory.current = tempDir.path;
      logger = _MockLogger();
      when(() => logger.info(any())).thenReturn(null);
      when(() => logger.detail(any())).thenReturn(null);
      when(() => logger.err(any())).thenReturn(null);
      runner = CommandRunner<int>('test', 'test')
        ..addCommand(SymbolicateCommand(logger: logger));
    });

    tearDown(() async {
      Directory.current = Directory.systemTemp.path;
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
      await cwdLock.release();
    });

    test('symbolicates a trace file using the default map path', () async {
      Directory('build').createSync(recursive: true);
      File('build/symbol_map.json').writeAsStringSync(mapJson);
      File('trace.txt').writeAsStringSync(trace);

      final exitCode = await runner.run(['symbolicate', 'trace.txt']);

      expect(exitCode, ExitCode.success.code);
      verify(
        () => logger.info(
          any(
            that: allOf(
              contains('Secret.value'),
              contains('package:app/x.dart:3:5'),
              isNot(contains('a.b')),
            ),
          ),
        ),
      ).called(1);
    });

    test('honors an explicit --symbol-map path', () async {
      File('map.json').writeAsStringSync(mapJson);
      File('trace.txt').writeAsStringSync(trace);

      final exitCode = await runner.run([
        'symbolicate',
        'trace.txt',
        '--symbol-map',
        '${tempDir.path}/map.json',
      ]);

      expect(exitCode, ExitCode.success.code);
      verify(
        () => logger.info(any(that: contains('Secret.value'))),
      ).called(1);
    });

    test('throws ConfigException when the symbol map is missing', () async {
      File('trace.txt').writeAsStringSync(trace);
      await expectLater(
        runner.run(['symbolicate', 'trace.txt']),
        throwsA(isA<ConfigException>()),
      );
    });

    test('throws ConfigException when the trace file is missing', () async {
      Directory('build').createSync(recursive: true);
      File('build/symbol_map.json').writeAsStringSync(mapJson);
      await expectLater(
        runner.run(['symbolicate', 'nope.txt']),
        throwsA(isA<ConfigException>()),
      );
    });

    test('throws ConfigException on a non-symbol-map JSON document', () async {
      Directory('build').createSync(recursive: true);
      File('build/symbol_map.json').writeAsStringSync('{"not":"a map"}');
      File('trace.txt').writeAsStringSync(trace);
      await expectLater(
        runner.run(['symbolicate', 'trace.txt']),
        throwsA(isA<ConfigException>()),
      );
    });
  });
}

class _MockLogger extends Mock implements Logger {}
