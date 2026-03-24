import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:refractor/src/cli/commands/build_command.dart';
import 'package:refractor/src/cli/reporting/github_reporter.dart';
import 'package:refractor/src/config/model/refractor_config.dart';
import 'package:refractor/src/engine/engine.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/symbol_table.dart';
import 'package:refractor/src/exceptions/refractor_exception.dart';
import 'package:test/test.dart';

void main() {
  group('BuildCommand', () {
    late Directory tempDir;
    late String originalCurrentDir;
    late CommandRunner<int> runner;
    late _MockLogger logger;
    late File summaryFile;

    setUp(() async {
      originalCurrentDir = Directory.current.path;
      tempDir = await Directory.systemTemp.createTemp('refractor_build_test_');
      Directory.current = tempDir.path;
      summaryFile = File('${tempDir.path}/github_step_summary.md');
      logger = _MockLogger();
      when(() => logger.detail(any())).thenReturn(null);
      when(() => logger.info(any())).thenReturn(null);
      when(() => logger.success(any())).thenReturn(null);
      when(() => logger.err(any())).thenReturn(null);

      runner = CommandRunner<int>('test', 'test')
        ..addCommand(BuildCommand(logger: logger));
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
      verify(
        () => logger.info(any(that: contains('✅ Build report:'))),
      ).called(1);
    });

    test(
      'emits rendered report and returns software code on failure',
      () async {
        runner = CommandRunner<int>('test', 'test')
          ..addCommand(
            _FakeBuildCommand(
              logger: logger,
              result: BuildResult(
                outputPath: 'build/out.dill',
                symbolTable: SymbolTable(),
                passesRun: ['string_encrypt'],
                reports: const [
                  PassReport(
                    passName: 'string_encrypt',
                    message: 'boom',
                  ),
                ],
                failures: [
                  PassFailureRecord(
                    passName: 'string_encrypt',
                    error: Exception('kaboom'),
                  ),
                ],
              ),
            ),
          );

        File('pubspec.yaml').writeAsStringSync('name: sample_app\n');
        File('refractor.yaml').writeAsStringSync('''
passes:
  rename: false
  string_encrypt: true
''');
        Directory('lib').createSync(recursive: true);
        File(
          'lib/main.dart',
        ).writeAsStringSync('void main() { print("ok"); }\n');

        final exitCode = await runner.run([
          'build',
          '--target',
          'kernel',
          '--input',
          'lib/main.dart',
          '--output',
          'build',
        ]);

        expect(exitCode, ExitCode.software.code);
        expect(File('symbol_map.json').existsSync(), isFalse);
        verify(
          () => logger.info(
            any(
              that: contains(
                'Build report: 0 pass(es) succeeded, 1 pass(es) failed.',
              ),
            ),
          ),
        ).called(1);
        verify(
          () =>
              logger.err('Build failed: one or more passes reported failure.'),
        ).called(1);
      },
    );

    test('writes GitHub summary when GITHUB_STEP_SUMMARY is set', () async {
      runner = CommandRunner<int>('test', 'test')
        ..addCommand(
          _FakeBuildCommand(
            logger: logger,
            reporter: GitHubReporter(
              logger,
              environment: {'GITHUB_STEP_SUMMARY': summaryFile.path},
            ),
            result: BuildResult(
              outputPath: 'build/out.dill',
              symbolTable: SymbolTable(),
              passesRun: ['rename'],
              reports: const [
                PassReport(
                  passName: 'rename',
                  metrics: [PassMetric(key: 'classes', value: 1)],
                ),
              ],
            ),
          ),
        );

      File('pubspec.yaml').writeAsStringSync('name: sample_app\n');
      File('refractor.yaml').writeAsStringSync('''
passes:
  rename: true
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
      expect(
        summaryFile.readAsStringSync(),
        contains('# ✅ Refractor Build Summary'),
      );
      expect(summaryFile.readAsStringSync(), contains('## ✅ rename'));
      verify(
        () => logger.info(
          any(that: contains('✅ Build report: 1 pass(es) succeeded.')),
        ),
      ).called(1);
    });

    test('appends GitHub summary instead of overwriting', () async {
      summaryFile.writeAsStringSync('Existing content\n');

      runner = CommandRunner<int>('test', 'test')
        ..addCommand(
          _FakeBuildCommand(
            logger: logger,
            reporter: GitHubReporter(
              logger,
              environment: {'GITHUB_STEP_SUMMARY': summaryFile.path},
            ),
            result: BuildResult(
              outputPath: 'build/out.dill',
              symbolTable: SymbolTable(),
              passesRun: ['rename'],
              reports: const [
                PassReport(
                  passName: 'rename',
                  metrics: [PassMetric(key: 'classes', value: 1)],
                ),
              ],
            ),
          ),
        );

      File('pubspec.yaml').writeAsStringSync('name: sample_app\n');
      File('refractor.yaml').writeAsStringSync('''
passes:
  rename: true
  string_encrypt: false
''');
      Directory('lib').createSync(recursive: true);
      File('lib/main.dart').writeAsStringSync('void main() { print("ok"); }\n');

      await runner.run([
        'build',
        '--target',
        'kernel',
        '--input',
        'lib/main.dart',
        '--output',
        'build',
      ]);

      final contents = summaryFile.readAsStringSync();
      expect(contents, startsWith('Existing content\n'));
      expect(contents, contains('# ✅ Refractor Build Summary'));
      verify(
        () => logger.info(
          any(that: contains('✅ Build report: 1 pass(es) succeeded.')),
        ),
      ).called(1);
    });

    test('writes GitHub summary for failed builds too', () async {
      runner = CommandRunner<int>('test', 'test')
        ..addCommand(
          _FakeBuildCommand(
            logger: logger,
            reporter: GitHubReporter(
              logger,
              environment: {'GITHUB_STEP_SUMMARY': summaryFile.path},
            ),
            result: BuildResult(
              outputPath: 'build/out.dill',
              symbolTable: SymbolTable(),
              passesRun: ['string_encrypt'],
              reports: const [
                PassReport(passName: 'string_encrypt', message: 'boom'),
              ],
              failures: [
                PassFailureRecord(
                  passName: 'string_encrypt',
                  error: Exception('kaboom'),
                ),
              ],
            ),
          ),
        );

      File('pubspec.yaml').writeAsStringSync('name: sample_app\n');
      File('refractor.yaml').writeAsStringSync('''
passes:
  rename: false
  string_encrypt: true
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

      expect(exitCode, ExitCode.software.code);
      expect(
        summaryFile.readAsStringSync(),
        contains('# ⚠️ Refractor Build Summary'),
      );
      expect(
        summaryFile.readAsStringSync(),
        contains('Error: Exception: kaboom'),
      );
      verify(
        () => logger.info(
          any(
            that: contains(
              'Build report: 0 pass(es) succeeded, 1 pass(es) failed.',
            ),
          ),
        ),
      ).called(1);
    });

    test(
      'skips GitHub summary emission when GITHUB_STEP_SUMMARY is absent',
      () async {
        runner = CommandRunner<int>('test', 'test')
          ..addCommand(
            _FakeBuildCommand(
              logger: logger,
              result: BuildResult(
                outputPath: 'build/out.dill',
                symbolTable: SymbolTable(),
                passesRun: ['rename'],
                reports: const [
                  PassReport(
                    passName: 'rename',
                    metrics: [PassMetric(key: 'classes', value: 1)],
                  ),
                ],
              ),
            ),
          );

        File('pubspec.yaml').writeAsStringSync('name: sample_app\n');
        File('refractor.yaml').writeAsStringSync('''
passes:
  rename: true
  string_encrypt: false
''');
        Directory('lib').createSync(recursive: true);
        File(
          'lib/main.dart',
        ).writeAsStringSync('void main() { print("ok"); }\n');

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
        expect(summaryFile.existsSync(), isFalse);
      },
    );

    test('soft-fails when GitHub summary writing throws', () async {
      runner = CommandRunner<int>('test', 'test')
        ..addCommand(
          _FakeBuildCommand(
            logger: logger,
            reporter: GitHubReporter(
              logger,
              environment: {'GITHUB_STEP_SUMMARY': summaryFile.path},
            ),
            result: BuildResult(
              outputPath: 'build/out.dill',
              symbolTable: SymbolTable(),
              passesRun: ['rename'],
              reports: const [
                PassReport(
                  passName: 'rename',
                  metrics: [PassMetric(key: 'classes', value: 1)],
                ),
              ],
            ),
          ),
        );

      File('pubspec.yaml').writeAsStringSync('name: sample_app\n');
      File('refractor.yaml').writeAsStringSync('''
passes:
  rename: true
  string_encrypt: false
''');
      Directory('lib').createSync(recursive: true);
      File('lib/main.dart').writeAsStringSync('void main() { print("ok"); }\n');
      if (summaryFile.existsSync()) {
        summaryFile.deleteSync();
      }
      Directory(summaryFile.path).createSync(recursive: true);

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
      verify(
        () => logger.detail(
          any(that: contains('GitHub summary emission failed:')),
        ),
      ).called(1);
    });

    test(
      'logs text output even when GitHub summary reporter has no summary path',
      () async {
        runner = CommandRunner<int>('test', 'test')
          ..addCommand(
            _FakeBuildCommand(
              logger: logger,
              reporter: GitHubReporter(logger),
              result: BuildResult(
                outputPath: 'build/out.dill',
                symbolTable: SymbolTable(),
                passesRun: ['rename'],
                reports: const [
                  PassReport(
                    passName: 'rename',
                    metrics: [PassMetric(key: 'classes', value: 1)],
                  ),
                ],
              ),
            ),
          );

        File('pubspec.yaml').writeAsStringSync('name: sample_app\n');
        File('refractor.yaml').writeAsStringSync('''
passes:
  rename: true
  string_encrypt: false
''');
        Directory('lib').createSync(recursive: true);
        File(
          'lib/main.dart',
        ).writeAsStringSync('void main() { print("ok"); }\n');

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
        verify(
          () => logger.info(
            any(that: contains('✅ Build report: 1 pass(es) succeeded.')),
          ),
        ).called(1);
      },
    );
  });
}

class _MockLogger extends Mock implements Logger {}

class _FakeBuildCommand extends BuildCommand {
  _FakeBuildCommand({
    required this.result,
    super.logger,
    super.reporter,
  });

  final BuildResult result;

  @override
  Future<BuildResult> runBuild({
    required BuildRequest request,
    required RefractorConfig config,
  }) async {
    return result;
  }
}
