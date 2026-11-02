@TestOn('vm')
@Tags(['integration'])
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:refractor/src/config/model/refractor_config.dart';
import 'package:refractor/src/engine/compiler/dart_compiler.dart';
import 'package:refractor/src/engine/engine.dart';
import 'package:refractor/src/engine/kernel/file_kernel_io.dart';
import 'package:test/test.dart';

/// Direct static calls of several shapes: an `int` result (cast back with
/// `as int`), a `void` result (no cast), a nested call in an argument, and a
/// `String` result.
const _program = r'''
int fee(int amount) => amount ~/ 40;

void report(String label, int value) {
  print('$label=$value');
}

String tag(bool ok) => ok ? 'ok' : 'fail';

void main() {
  print(fee(1200));
  report('nested', fee(fee(64000)));
  print(tag(fee(80) == 2));
}
''';

/// `call_indirection` on its own.
const _configYaml = '''
refractor:
  verbose: false
  passes:
    call_indirection: true
''';

/// `string_encrypt` first, so its `refractorDecode(bytes, key)` calls are
/// routed through the forwarder too.
const _withStringEncryptYaml = '''
refractor:
  verbose: false
  passes:
    string_encrypt:
      seed: 3
    call_indirection: true
''';

/// A routed callee with a name distinctive enough to find with `strings`, plus
/// a tear-off with a named parameter called through the closure, whose label
/// must survive rename.
const _sentinelProgram = r'''
int refractorSentinelCallee(int amount) => amount * 3 + 1;

String labelled(int value, {String prefix = '?'}) => '$prefix$value';

void main() {
  print(refractorSentinelCallee(13));
  final format = labelled;
  print(format(refractorSentinelCallee(2), prefix: '#'));
}
''';

const _sentinelName = 'refractorSentinelCallee';

/// `rename` and `call_indirection` in both orders.
const _passOrders = {
  'rename then call_indirection': '''
refractor:
  verbose: false
  passes:
    rename: true
    call_indirection: true
''',
  'call_indirection then rename': '''
refractor:
  verbose: false
  passes:
    call_indirection: true
    rename: true
''',
};

void main() {
  late Directory tempDir;
  late String sourcePath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('refractor_call_ind_');
    sourcePath = p.join(tempDir.path, 'main.dart');
    File(sourcePath).writeAsStringSync(_program);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  /// Obfuscates [sourcePath] with [configYaml], builds it for [target], runs
  /// it, and returns the `call_indirection` count with the program's stdout
  /// and the path of the built output.
  Future<({int indirected, String output, String outputPath})> buildAndRun(
    Target target,
    String configYaml,
  ) async {
    final outputPath = p.join(tempDir.path, 'main${target.extension}');
    final result =
        await RefractorEngine(
          compiler: DartCompiler(),
          kernelIO: FileKernelIO(),
        ).run(
          config: RefractorConfig.fromYaml(configYaml),
          request: BuildRequest(
            input: sourcePath,
            output: outputPath,
            target: target,
            workDirectory: tempDir.path,
            projectRootUri: Uri.directory('${tempDir.path}/'),
            projectPackageName: null,
          ),
        );

    final report = result.passResults.reports.singleWhere(
      (r) => r.passName == 'call_indirection',
    );
    final output = _run(switch (target) {
      Target.exe => Process.runSync(outputPath, []),
      Target.jit => Process.runSync('dart', ['run', outputPath]),
      Target.aot => Process.runSync(_dartAotRuntime(), [outputPath]),
      Target.kernel => Process.runSync('dart', [outputPath]),
    });
    return (
      indirected: int.parse(report.metadata['calls_indirected'] ?? '0'),
      output: output,
      outputPath: outputPath,
    );
  }

  // Regression: the pass used to emit a bare `StaticTearOff` expression,
  // which only the kernel target tolerated. The VM rejects it (JIT: "Unexpected
  // tag 17 (StaticTearOff)"; AOT: type-flow analysis "Unexpected node
  // StaticTearOff") because the CFE always lowers static tear-offs to
  // constants.
  for (final target in [Target.exe, Target.jit, Target.aot]) {
    test('call_indirection: ${target.name} output matches the plain '
        'program', () async {
      final expected = _run(Process.runSync('dart', ['run', sourcePath]));

      final run = await buildAndRun(target, _configYaml);

      expect(
        run.indirected,
        equals(6),
        reason: 'all six calls should be routed through the forwarder',
      );
      expect(run.output, equals(expected));
      expect(run.output, equals('30\nnested=40\nok'));
    });
  }

  // Regression: string_encrypt emitted its byte list as an untyped
  // (`List<dynamic>`) literal. A direct call to `refractorDecode(List<int>,
  // int)` never checks that, but `Function.apply` in the forwarder does and
  // threw "type 'List<dynamic>' is not a subtype of type 'List<int>'".
  test(
    'string_encrypt + call_indirection: exe decodes routed strings',
    () async {
      final run = await buildAndRun(Target.exe, _withStringEncryptYaml);

      expect(
        run.indirected,
        greaterThan(6),
        reason:
            'the decoder calls should be routed as well as the six '
            'program calls',
      );
      expect(run.output, equals('30\nnested=40\nok'));
    },
  );

  // Regression: helpers are injected before any pass runs, so a `rename`
  // listed first renamed `refractorCall` and call_indirection, looking it up
  // by name, indirected nothing. Listed after, rename kept every routed callee
  // (and its parameters) under its original name because the forwarder tears
  // it off, and AOT then kept that name in the binary for the closure.
  for (final MapEntry(key: order, value: configYaml) in _passOrders.entries) {
    test('$order: exe indirects calls and renames the callees', () async {
      File(sourcePath).writeAsStringSync(_sentinelProgram);

      final run = await buildAndRun(Target.exe, configYaml);

      expect(run.indirected, greaterThan(0));
      expect(run.output, equals('40\n#7'));

      final strings = Process.runSync('strings', [run.outputPath]);
      if (strings.exitCode != 0) {
        markTestSkipped('`strings` is unavailable: ${strings.stderr}');
        return;
      }
      final stringsOutput = strings.stdout as String;
      for (final name in [_sentinelName, 'refractorCall']) {
        expect(
          stringsOutput.contains(name),
          isFalse,
          reason: '`$name` should have been renamed out of the binary',
        );
      }
    });
  }
}

String _run(ProcessResult result) {
  if (result.exitCode != 0) {
    fail(
      'Process exited with ${result.exitCode}:\n'
      'stdout: ${result.stdout}\n'
      'stderr: ${result.stderr}',
    );
  }
  return (result.stdout as String).trim();
}

String _dartAotRuntime() {
  final sibling = File(
    p.join(File(Platform.resolvedExecutable).parent.path, 'dartaotruntime'),
  );
  if (sibling.existsSync()) return sibling.path;
  fail(
    'Unable to locate dartaotruntime next to ${Platform.resolvedExecutable}.',
  );
}
