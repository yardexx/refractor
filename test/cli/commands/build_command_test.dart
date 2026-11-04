import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:refractor/src/cli/commands/build_command.dart';
import 'package:refractor/src/cli/reporting/github_reporter.dart';
import 'package:refractor/src/config/model/refractor_config.dart';
import 'package:refractor/src/engine/engine.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/exceptions/refractor_exception.dart';
import 'package:test/test.dart';

import '../../helpers/cwd_test_lock.dart';

void main() {
  group('BuildCommand', () {
    late CwdTestLock cwdLock;
    late Directory tempDir;
    late CommandRunner<int> runner;
    late _MockLogger logger;
    late File summaryFile;

    setUp(() async {
      cwdLock = await CwdTestLock.acquire();
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
      Directory.current = Directory.systemTemp.path;
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
      await cwdLock.release();
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
refractor:
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
      ]);

      expect(exitCode, ExitCode.success.code);
      expect(File('build/out.dill').existsSync(), isTrue);
      expect(File('build/out.dill').lengthSync(), greaterThan(0));
      expect(File('build/build_artifacts.json').existsSync(), isFalse);
      verify(
        () => logger.info(any(that: contains('✅ Build report:'))),
      ).called(1);
    });

    test('emits a versioned symbol map when rename renames symbols', () async {
      File('pubspec.yaml').writeAsStringSync('name: sample_app\n');
      File('refractor.yaml').writeAsStringSync('''
refractor:
  passes:
    rename: true
    string_encrypt: false
''');
      Directory('lib').createSync(recursive: true);
      File('lib/main.dart').writeAsStringSync('''
class Secret {
  int value() => 42;
}

void main() {
  print(Secret().value());
}
''');

      final exitCode = await runner.run([
        'build',
        '--target',
        'kernel',
        '--input',
        'lib/main.dart',
      ]);

      expect(exitCode, ExitCode.success.code);
      final file = File('build/symbol_map.json');
      expect(file.existsSync(), isTrue);
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(json['version'], 1);
      expect(json['kind'], 'refractor-symbol-map');
      final symbols = (json['symbols'] as Map).cast<String, Object?>();
      expect(symbols, isNotEmpty);
      // The originals (the map's values) must include the renamed declarations.
      expect(symbols.values, containsAll(<Object?>['Secret', 'value']));
    });

    test(
      'removes a stale symbol map when a build renames nothing',
      () async {
        File('pubspec.yaml').writeAsStringSync('name: sample_app\n');
        File('refractor.yaml').writeAsStringSync('''
refractor:
  passes:
    rename: false
    string_encrypt: false
''');
        Directory('build').createSync(recursive: true);
        File('build/symbol_map.json').writeAsStringSync('{"stale": true}');
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
        ]);

        expect(exitCode, ExitCode.success.code);
        expect(File('build/symbol_map.json').existsSync(), isFalse);
      },
    );

    test('raises logger level to verbose when config enables it', () async {
      File('pubspec.yaml').writeAsStringSync('name: sample_app\n');
      File('refractor.yaml').writeAsStringSync('''
refractor:
  verbose: true
  passes:
    rename: false
    string_encrypt: false
''');
      Directory('lib').createSync(recursive: true);
      File('lib/main.dart').writeAsStringSync('void main() { print("ok"); }\n');

      final exitCode = await runner.run(['build', '--target', 'kernel']);

      expect(exitCode, ExitCode.success.code);
      verify(() => logger.level = Level.verbose).called(1);
    });

    test(
      'removes stale artifact json when a successful build has no artifacts',
      () async {
        File('pubspec.yaml').writeAsStringSync('name: sample_app\n');
        File('refractor.yaml').writeAsStringSync('''
refractor:
  passes:
    rename: false
    string_encrypt: false
''');
        Directory('build').createSync(recursive: true);
        Directory('lib').createSync(recursive: true);
        File(
          'lib/main.dart',
        ).writeAsStringSync('void main() { print("ok"); }\n');
        File(
          'build/build_artifacts.json',
        ).writeAsStringSync('{"passes":{"rename":{"symbol_map":{"a":"b"}}}}');

        final exitCode = await runner.run([
          'build',
          '--target',
          'kernel',
          '--input',
          'lib/main.dart',
        ]);

        expect(exitCode, ExitCode.success.code);
        expect(File('build/build_artifacts.json').existsSync(), isFalse);
      },
    );

    test(
      'emits rendered report and returns software code on failure',
      () async {
        runner = CommandRunner<int>('test', 'test')
          ..addCommand(
            _FakeBuildCommand(
              logger: logger,
              result: BuildResult(
                outputPath: 'build/out.dill',
                passesRun: ['string_encrypt'],
                passResults: PassResults(),
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
refractor:
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
        ]);

        expect(exitCode, ExitCode.software.code);
        expect(File('build/build_artifacts.json').existsSync(), isFalse);
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
              passesRun: ['rename'],
              passResults: PassResults(),
              reports: const [
                PassReport(
                  passName: 'rename',
                  metadata: {'classes': '1'},
                ),
              ],
            ),
          ),
        );

      File('pubspec.yaml').writeAsStringSync('name: sample_app\n');
      File('refractor.yaml').writeAsStringSync('''
refractor:
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
              passesRun: ['rename'],
              passResults: PassResults(),
              reports: const [
                PassReport(
                  passName: 'rename',
                  metadata: {'classes': '1'},
                ),
              ],
            ),
          ),
        );

      File('pubspec.yaml').writeAsStringSync('name: sample_app\n');
      File('refractor.yaml').writeAsStringSync('''
refractor:
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
              passesRun: ['string_encrypt'],
              passResults: PassResults(),
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
refractor:
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
                passesRun: ['rename'],
                passResults: PassResults(),
                reports: const [
                  PassReport(
                    passName: 'rename',
                    metadata: {'classes': '1'},
                  ),
                ],
              ),
            ),
          );

        File('pubspec.yaml').writeAsStringSync('name: sample_app\n');
        File('refractor.yaml').writeAsStringSync('''
refractor:
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
              passesRun: ['rename'],
              passResults: PassResults(),
              reports: const [
                PassReport(
                  passName: 'rename',
                  metadata: {'classes': '1'},
                ),
              ],
            ),
          ),
        );

      File('pubspec.yaml').writeAsStringSync('name: sample_app\n');
      File('refractor.yaml').writeAsStringSync('''
refractor:
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
                passesRun: ['rename'],
                passResults: PassResults(),
                reports: const [
                  PassReport(
                    passName: 'rename',
                    metadata: {'classes': '1'},
                  ),
                ],
              ),
            ),
          );

        File('pubspec.yaml').writeAsStringSync('name: sample_app\n');
        File('refractor.yaml').writeAsStringSync('''
refractor:
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
        ]);

        expect(exitCode, ExitCode.success.code);
        verify(
          () => logger.info(
            any(that: contains('✅ Build report: 1 pass(es) succeeded.')),
          ),
        ).called(1);
      },
    );

    test('writes generic artifact json when pass artifacts exist', () async {
      final passResults = PassResults()
        ..addArtifact(
          'rename',
          const _JsonArtifact({
            'symbol_map': {'a': 'b'},
          }),
        )
        ..addArtifact(
          'string_encrypt',
          const _JsonArtifact({'records': []}),
        );

      runner = CommandRunner<int>('test', 'test')
        ..addCommand(
          _FakeBuildCommand(
            logger: logger,
            result: BuildResult(
              outputPath: 'build/out.dill',
              passesRun: ['rename', 'string_encrypt'],
              passResults: passResults,
              reports: const [
                PassReport(passName: 'rename'),
                PassReport(passName: 'string_encrypt'),
              ],
            ),
          ),
        );

      File('pubspec.yaml').writeAsStringSync('name: sample_app\n');
      File('refractor.yaml').writeAsStringSync('''
refractor:
  passes:
    rename: true
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
      ]);

      expect(exitCode, ExitCode.success.code);
      final json =
          jsonDecode(
                File('build/build_artifacts.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(json, {
        'passes': {
          'rename': {
            'symbol_map': {'a': 'b'},
          },
          'string_encrypt': {
            'records': <Object?>[],
          },
        },
      });
    });
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
  BuildResult runBuild({
    required BuildRequest request,
    required RefractorConfig config,
  }) {
    return result;
  }
}

final class _JsonArtifact extends PassArtifact {
  const _JsonArtifact(this.value);

  final Map<String, Object?> value;

  @override
  Map<String, Object?> toJson() => value;
}
