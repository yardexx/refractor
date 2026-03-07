import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:refractor/src/cli/commands/build_command.dart';
import 'package:refractor/src/exceptions/refractor_exception.dart';
import 'package:test/test.dart';

void main() {
  group('BuildCommand', () {
    late Directory tempDir;
    late String originalCurrentDir;
    late CommandRunner<int> runner;

    setUp(() async {
      originalCurrentDir = Directory.current.path;
      tempDir = await Directory.systemTemp.createTemp('refractor_build_test_');
      Directory.current = tempDir.path;

      runner = CommandRunner<int>('test', 'test')..addCommand(BuildCommand());
    });

    tearDown(() async {
      Directory.current = originalCurrentDir;
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('throws ConfigException when refractor.yaml is missing', () async {
      File('pubspec.yaml').writeAsStringSync('name: sample_app\n');
      Directory('lib').createSync(recursive: true);
      File('lib/main.dart').writeAsStringSync('void main() {}\n');

      await expectLater(
        runner.run(['build', '--target', 'kernel']),
        throwsA(isA<ConfigException>()),
      );
    });

    test('builds kernel output for a minimal project', () async {
      File('pubspec.yaml').writeAsStringSync('name: sample_app\n');
      File('refractor.yaml').writeAsStringSync('''
passes:
  rename: false
  string_encrypt: false
''');
      Directory('lib').createSync(recursive: true);
      File('lib/main.dart').writeAsStringSync('void main() { print("ok"); }\n');

      final exitCode = await runner.run([
        'build',
        '--target',
        'kernel',
        '--input',
        'lib/main.dart',
        '--output',
        'build',
      ]);

      expect(exitCode, ExitCode.success.code);
      expect(File('build/out.dill').existsSync(), isTrue);
      expect(File('build/out.dill').lengthSync(), greaterThan(0));
      expect(File('symbol_map.json').existsSync(), isTrue);
    });
  });
}
