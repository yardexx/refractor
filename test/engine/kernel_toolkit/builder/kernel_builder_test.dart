@Tags(['integration'])
library;

import 'dart:io';

import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/compiler/compiler.dart';
import 'package:refractor/src/engine/compiler/dart_compiler.dart';
import 'package:refractor/src/engine/kernel/file_kernel_io.dart';
import 'package:refractor/src/engine/kernel_toolkit/builder/kernel_builder.dart';
import 'package:test/test.dart';

/// Strengthens every `if` condition with an always-true opaque predicate built
/// by [KernelBuilder]: `cond` becomes `cond && (7 * 7 >= 0)`.
class _StrengthenConditions extends Transformer {
  _StrengthenConditions(this._builder);

  final KernelBuilder _builder;

  @override
  TreeNode visitIfStatement(IfStatement node) {
    super.visitIfStatement(node);
    final opaqueTrue = _builder.ge(
      _builder.mul(_builder.intLit(7), _builder.intLit(7)),
      _builder.intLit(0),
    );
    node.condition = _builder.and(node.condition, opaqueTrue)..parent = node;
    return node;
  }
}

void main() {
  group('KernelBuilder', () {
    late Directory dir;
    final Compiler compiler = DartCompiler();
    final io = FileKernelIO();

    setUp(() => dir = Directory.systemTemp.createTempSync('kb_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    test(
      'builds an AOT-valid opaque predicate that preserves behaviour',
      () {
        final appDart = '${dir.path}/app.dart';
        final appDill = '${dir.path}/app.dill';
        File(appDart).writeAsStringSync('''
void main() {
  final x = int.parse('5');
  if (x > 3) {
    print('yes');
  } else {
    print('no');
  }
}
''');
        compiler.compileToKernel(appDart, appDill);
        final component = io.load(appDill);

        component.transformChildren(
          _StrengthenConditions(KernelBuilder(component)),
        );

        final outDill = '${dir.path}/out.dill';
        io.write(component, outDill);
        final exe = '${dir.path}/app_exe';
        compiler.compileToTarget(outDill, exe, Target.exe);

        final result = Process.runSync(exe, const []);
        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect(result.stdout.toString().trim(), 'yes');
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
