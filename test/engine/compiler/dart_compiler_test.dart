import 'dart:io';

import 'package:refractor/src/engine/compiler/compiler.dart';
import 'package:refractor/src/engine/compiler/dart_compiler.dart';
import 'package:refractor/src/exceptions/refractor_exception.dart';
import 'package:test/test.dart';

void main() {
  group('DartCompiler', () {
    test('compileToKernel wraps a failed process in CompilationException', () {
      final outputPath =
          '${Directory.systemTemp.path}/'
          'dart_compiler_test_${DateTime.now().microsecondsSinceEpoch}.dill';

      expect(
        () => DartCompiler().compileToKernel(
          '/nonexistent/dart_compiler_test_fixture.dart',
          outputPath,
        ),
        throwsA(isA<CompilationException>()),
      );
    });

    test('compileToTarget wraps a failed process in CompilationException', () {
      final outputPath =
          '${Directory.systemTemp.path}/'
          'dart_compiler_test_${DateTime.now().microsecondsSinceEpoch}';

      expect(
        () => DartCompiler().compileToTarget(
          '/nonexistent/dart_compiler_test_fixture.dill',
          outputPath,
          Target.kernel,
        ),
        throwsA(isA<CompilationException>()),
      );
    });

    test(
      'jit target does not pass its own options to the training run',
      () {
        final dir = Directory.systemTemp.createTempSync('dart_compiler_jit_');
        addTearDown(() => dir.deleteSync(recursive: true));

        // The training run fails on any argument that is not a number, so a
        // stray `-o <out>` would break the build.
        final source = File('${dir.path}/main.dart')
          ..writeAsStringSync('''
void main(List<String> args) {
  if (args.isNotEmpty) print(int.parse(args[0]) * 2);
}
''');
        final dillPath = '${dir.path}/main.dill';
        final snapshotPath = '${dir.path}/main.jit';

        DartCompiler()
          ..compileToKernel(source.path, dillPath)
          ..compileToTarget(dillPath, snapshotPath, Target.jit);

        final result = Process.runSync('dart', [snapshotPath, '21']);
        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect((result.stdout as String).trim(), '42');
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
