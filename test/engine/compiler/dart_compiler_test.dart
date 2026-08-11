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
  });
}
