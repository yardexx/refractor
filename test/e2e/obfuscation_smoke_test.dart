// Too strict
// ignore_for_file: lines_longer_than_80_chars

@TestOn('vm')
@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:refractor/src/config/model/refractor_config.dart';
import 'package:refractor/src/engine/compiler/dart_compiler.dart';
import 'package:refractor/src/engine/engine.dart';
import 'package:refractor/src/engine/kernel/file_kernel_io.dart';
import 'package:refractor/src/utils/result.dart';
import 'package:test/test.dart';

/// Minimal Dart program that exercises diverse language features.
///
/// Output is fully deterministic — no timestamps, no randomness.
const _testProgram = r'''
import 'dart:math';

void main() {
  final greeter = Greeter(prefix: 'Hello');
  print(greeter.greet('World'));

  final calc = Calculator();
  print('sum: ${calc.add(2, 3)}');
  print('factorial: ${factorial(5)}');

  final items = ['alpha', 'beta', 'gamma'];
  print('upper: ${items.map((s) => s.toUpperCase()).join(', ')}');

  final lazy = Lazy<int>(() => 42);
  print('lazy: ${lazy.value}');

  try {
    throwIfNegative(-1);
  } catch (e) {
    print('caught: $e');
  }
}

abstract class Named {
  String get name;
}

mixin Prefixed {
  String get prefix;
  String format(String text) => '$prefix $text';
}

class Greeter with Prefixed implements Named {
  @override
  final String prefix;

  Greeter({required this.prefix});

  @override
  String get name => 'Greeter';

  String greet(String target) => format(target);
}

class Calculator {
  int add(int a, int b) => a + b;
}

int factorial(int n) => n <= 1 ? 1 : n * factorial(n - 1);

void throwIfNegative(int value) {
  if (value < 0) {
    throw ArgumentError.value(value, 'value', 'Must be >= 0');
  }
}

class Lazy<T> {
  T? _cached;
  final T Function() _factory;

  Lazy(this._factory);

  T get value => _cached ??= _factory();
}
''';

const _expectedOutput = '''
Hello World
sum: 5
factorial: 120
upper: ALPHA, BETA, GAMMA
lazy: 42
caught: Invalid argument (value): Must be >= 0: -1
''';

const _exampleExpectedLines = <String>[
  'app=KernelEdgeCases@0.1.0',
  'mode=active',
  'override=Hello World!',
  'sdkOverride=FancyRenderer(prefix: Hello)',
  'dynamic=Hello dynamic!',
  'dynamicField=dynamic-message',
  'construction=Payload(ctor) | Redirect(factory) | Redirect(9)',
  'locals=LOCAL',
  'excluded=entry:entry! | EntryPointPayload(payload) | EntryPointPayload(constructor)',
  'sourceOnly=top-level-function-alias,generic-top-level-alias,constructor-tear-off-alias,redirecting-factory-tear-off-alias,instantiated-factory-tear-off-alias,instance-method-tear-off-alias,final-static-field-alias,final-static-factory-alias,final-static-instantiated-factory-alias,mutable-function-alias',
  'secret=renderer-secret|vault-token|[audit] Hello mix!',
  'enum=idle,active,done',
  'interpolation=interpolated:Hello done!',
  'unusedCase=unused:shadow',
  'unused=15',
  '[VERBOSE] All arguments: --verbose',
];

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('refractor_e2e_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('E2E obfuscation smoke test', () {
    test('rename pass: obfuscated binary produces correct output', () async {
      final output = await _compileObfuscateRun(
        tempDir: tempDir,
        configYaml: '''
refractor:
  verbose: false
passes:
  rename: true
''',
      );
      expect(output, equals(_expectedOutput.trim()));
    });

    test(
      'rename + string_encrypt: obfuscated binary produces correct output',
      () async {
        final output = await _compileObfuscateRun(
          tempDir: tempDir,
          configYaml: '''
refractor:
  verbose: false
passes:
  rename: true
  string_encrypt:
    xor_key: 42
''',
        );
        expect(output, equals(_expectedOutput.trim()));
      },
    );

    test('example app: obfuscated binary builds and runs', () async {
      final output = await _buildAndRunExampleApp(
        tempDir: tempDir,
        arguments: const ['--verbose'],
      );

      for (final line in _exampleExpectedLines) {
        expect(output, contains(line));
      }
    });
  });
}

/// Compiles a test program, obfuscates it, compiles to exe, runs it,
/// and returns stdout.
Future<String> _compileObfuscateRun({
  required Directory tempDir,
  required String configYaml,
}) async {
  final sourcePath = '${tempDir.path}/main.dart';
  final exePath = '${tempDir.path}/main.exe';

  File(sourcePath).writeAsStringSync(_testProgram);

  // Parse config.
  final config = RefractorConfig.fromYaml(configYaml);

  // Run the engine pipeline.
  final engine = RefractorEngine(
    compiler: DartCompiler(),
    kernelIO: FileKernelIO(),
  );

  final result = await engine.run(
    config: config,
    request: BuildRequest(
      input: sourcePath,
      output: exePath,
      target: Target.exe,
      workDirectory: tempDir.path,
      projectRootUri: Uri.file('${tempDir.path}/'),
      projectPackageName: null,
    ),
  );

  switch (result) {
    case Ok():
      break;
    case Error(:final error):
      fail('Engine failed: $error');
  }

  // Run the compiled binary.
  final processResult = Process.runSync(exePath, []);
  if (processResult.exitCode != 0) {
    fail(
      'Binary exited with ${processResult.exitCode}:\n'
      'stdout: ${processResult.stdout}\n'
      'stderr: ${processResult.stderr}',
    );
  }

  return (processResult.stdout as String).trim();
}

Future<String> _buildAndRunExampleApp({
  required Directory tempDir,
  required List<String> arguments,
}) async {
  final repoRoot = Directory.current.path;
  final exampleRoot = '$repoRoot/example';
  final configYaml = File('$exampleRoot/refractor.yaml').readAsStringSync();
  final config = RefractorConfig.fromYaml(configYaml);

  final outputPath = '${tempDir.path}/example.exe';

  final engine = RefractorEngine(
    compiler: DartCompiler(),
    kernelIO: FileKernelIO(),
  );

  final result = await engine.run(
    config: config,
    request: BuildRequest(
      input: '$exampleRoot/bin/app.dart',
      output: outputPath,
      target: Target.exe,
      workDirectory: tempDir.path,
      projectRootUri: Uri.directory('$exampleRoot/'),
      projectPackageName: 'app',
    ),
  );

  switch (result) {
    case Ok():
      break;
    case Error(:final error):
      fail('Example engine build failed: $error');
  }

  final processResult = Process.runSync(outputPath, arguments);
  if (processResult.exitCode != 0) {
    fail(
      'Example binary exited with ${processResult.exitCode}:\n'
      'stdout: ${processResult.stdout}\n'
      'stderr: ${processResult.stderr}',
    );
  }

  return (processResult.stdout as String).trim();
}
