@Tags(['integration'])
library;

import 'dart:io';

import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/compiler/dart_compiler.dart';
import 'package:refractor/src/engine/kernel/file_kernel_io.dart';
import 'package:refractor/src/engine/kernel_toolkit/builder/kernel_builder.dart';
import 'package:test/test.dart';

void main() {
  group('KernelBuilder primitives', () {
    late Directory dir;
    late KernelBuilder b;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('kb_primitives');
      final app = '${dir.path}/app.dart';
      final dill = '${dir.path}/app.dill';
      File(app).writeAsStringSync('void main() {}');
      DartCompiler().compileToKernel(app, dill);
      b = KernelBuilder(FileKernelIO().load(dill));
    });

    tearDown(() => dir.deleteSync(recursive: true));

    test('builds literals and the int type', () {
      expect(b.intLit(1), isA<IntLiteral>());
      expect(b.boolLit(value: true), isA<BoolLiteral>());
      expect(b.intType, isA<InterfaceType>());
    });

    test('builds int arithmetic and bitwise invocations', () {
      for (final build in <Expression Function()>[
        () => b.mul(b.intLit(2), b.intLit(3)),
        () => b.add(b.intLit(2), b.intLit(3)),
        () => b.sub(b.intLit(2), b.intLit(3)),
        () => b.mod(b.intLit(2), b.intLit(3)),
        () => b.xor(b.intLit(2), b.intLit(3)),
        () => b.bitAnd(b.intLit(2), b.intLit(3)),
        () => b.shl(b.intLit(2), b.intLit(3)),
      ]) {
        expect(build(), isA<InstanceInvocation>());
      }
    });

    test('builds comparisons', () {
      for (final build in <Expression Function()>[
        () => b.ge(b.intLit(2), b.intLit(3)),
        () => b.gt(b.intLit(2), b.intLit(3)),
        () => b.le(b.intLit(2), b.intLit(3)),
        () => b.lt(b.intLit(2), b.intLit(3)),
      ]) {
        expect(build(), isA<InstanceInvocation>());
      }
    });

    test('builds logical operators', () {
      expect(
        b.and(b.boolLit(value: true), b.boolLit(value: false)),
        isA<LogicalExpression>(),
      );
      expect(
        b.or(b.boolLit(value: true), b.boolLit(value: false)),
        isA<LogicalExpression>(),
      );
      expect(b.not(b.boolLit(value: true)), isA<Not>());
    });
  });
}
