// Too strict
// ignore_for_file: lines_longer_than_80_chars

@TestOn('vm')
@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:refractor/src/config/model/refractor_config.dart';
import 'package:refractor/src/engine/compiler/dart_compiler.dart';
import 'package:refractor/src/engine/engine.dart';
import 'package:refractor/src/engine/kernel/file_kernel_io.dart';
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

const _callableAliasProgram = r'''
String topLevelNamed({required String value, bool debug = false}) {
  return debug ? 'top:$value' : value;
}

String alternateTopLevelNamed({required String value, bool debug = false}) {
  return 'alt:$value';
}

T genericEcho<T>({required T value, bool debug = false}) => value;

class Payload {
  final String value;

  Payload.named({required this.value, bool debug = false});

  String describe() => 'Payload($value)';
}

class RedirectPayload<T> {
  final T value;

  RedirectPayload.named({required this.value, bool debug = false});

  factory RedirectPayload.redirect({required T value, bool debug}) =
      RedirectPayload<T>.named;

  String describe() => 'Redirect($value)';
}

class Renderer {
  final String prefix;

  Renderer(this.prefix);

  String render({required String label, bool excited = false}) {
    final suffix = excited ? '!' : '';
    return '$prefix $label$suffix';
  }
}

class AliasHub {
  static final String Function({required String value, bool debug})
      finalTopLevelAlias = topLevelNamed;

  static final RedirectPayload<String> Function({
    required String value,
    bool debug,
  }) finalFactoryAlias = RedirectPayload<String>.redirect;
}

void main() {
  final renderer = Renderer('Hello');
  final topAlias = topLevelNamed;
  final genericAlias = genericEcho<int>;
  final ctorAlias = Payload.named;
  final factoryAlias = RedirectPayload<String>.redirect;
  final instantiatedFactoryAlias = RedirectPayload<int>.redirect;
  final instanceAlias = renderer.render;
  final staticAlias = AliasHub.finalTopLevelAlias;
  final staticFactoryAlias = AliasHub.finalFactoryAlias;
  String Function({required String value, bool debug}) mutableAlias =
      topLevelNamed;
  mutableAlias = alternateTopLevelNamed;

  print(topAlias(value: 'alias', debug: true));
  print(genericAlias(value: 7, debug: true));
  print(ctorAlias(value: 'ctor', debug: true).describe());
  print(factoryAlias(value: 'factory', debug: true).describe());
  print(instantiatedFactoryAlias(value: 9, debug: true).describe());
  print(instanceAlias(label: 'instance', excited: true));
  print(staticAlias(value: 'field', debug: true));
  print(staticFactoryAlias(value: 'field-factory', debug: true).describe());
  print(mutableAlias(value: 'mutable', debug: true));
}
''';

const _callableAliasExpectedOutput = '''
top:alias
7
Payload(ctor)
Redirect(factory)
Redirect(9)
Hello instance!
top:field
Redirect(field-factory)
alt:mutable
''';

const _exampleExpectedLines = <String>[
  'app=KernelEdgeCases@0.1.0',
  'mode=active',
  'override=Hello World!',
  'sdkOverride=FancyRenderer(prefix: Hello)',
  'dynamic=Hello dynamic!',
  'dynamicField=dynamic-message',
  'construction=Payload(ctor) | Redirect(factory) | Redirect(9)',
  'tearOffs=top:alias | 7 | Payload(ctor) | Redirect(factory) | Redirect(9)',
  'instanceTearOff=Hello instance!',
  'fieldAliases=top:field-alias | Redirect(field-factory) | Redirect(12)',
  'mutableAlias=alt:mutable',
  'locals=LOCAL',
  'excluded=entry:entry! | EntryPointPayload(payload) | EntryPointPayload(constructor)',
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

    test('rename pass: callable aliases survive obfuscated AOT', () async {
      final output = await _compileObfuscateRun(
        tempDir: tempDir,
        source: _callableAliasProgram,
        configYaml: '''
refractor:
  verbose: false
  passes:
    rename: true
''',
      );
      expect(output, equals(_callableAliasExpectedOutput.trim()));
    });

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
  String source = _testProgram,
}) async {
  final sourcePath = '${tempDir.path}/main.dart';
  final exePath = '${tempDir.path}/main.exe';

  File(sourcePath).writeAsStringSync(source);

  // Parse config.
  final config = RefractorConfig.fromYaml(configYaml);

  // Run the engine pipeline.
  final engine = RefractorEngine(
    compiler: DartCompiler(),
    kernelIO: FileKernelIO(),
  );

  await engine.run(
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
  final scriptPath = Platform.script.toFilePath();
  final repoRoot = p.normalize(
    p.join(p.dirname(scriptPath), '..', '..'),
  );
  final exampleRoot = '$repoRoot/example';
  final configYaml = File('$exampleRoot/refractor.yaml').readAsStringSync();
  final config = RefractorConfig.fromYaml(configYaml);

  final outputPath = '${tempDir.path}/example.exe';

  final engine = RefractorEngine(
    compiler: DartCompiler(),
    kernelIO: FileKernelIO(),
  );

  await engine.run(
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
