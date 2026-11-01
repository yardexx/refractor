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

/// `call_indirection` on its own: with `rename` also enabled the forwarder is
/// renamed before this pass resolves it, so nothing would be indirected.
const _configYaml = '''
refractor:
  verbose: false
  passes:
    call_indirection: true
''';

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

  // Regression: the pass used to emit a bare `StaticTearOff` expression,
  // which only the kernel target tolerated. The VM rejects it (JIT: "Unexpected
  // tag 17 (StaticTearOff)"; AOT: type-flow analysis "Unexpected node
  // StaticTearOff") because the CFE always lowers static tear-offs to
  // constants.
  for (final target in [Target.exe, Target.jit, Target.aot]) {
    test('call_indirection: ${target.name} output matches the plain '
        'program', () async {
      final expected = _run(Process.runSync('dart', ['run', sourcePath]));

      final outputPath = p.join(tempDir.path, 'main${target.extension}');
      final result =
          await RefractorEngine(
            compiler: DartCompiler(),
            kernelIO: FileKernelIO(),
          ).run(
            config: RefractorConfig.fromYaml(_configYaml),
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
      expect(
        int.parse(report.metadata['calls_indirected'] ?? '0'),
        equals(6),
        reason: 'all six calls should be routed through the forwarder',
      );

      final actual = _run(switch (target) {
        Target.exe => Process.runSync(outputPath, []),
        Target.jit => Process.runSync('dart', ['run', outputPath]),
        Target.aot => Process.runSync(_dartAotRuntime(), [outputPath]),
        Target.kernel => Process.runSync('dart', [outputPath]),
      });
      expect(actual, equals(expected));
      expect(actual, equals('30\nnested=40\nok'));
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
