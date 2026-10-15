@Tags(['integration'])
library;

import 'dart:io';

import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/compiler/compiler.dart';
import 'package:refractor/src/engine/compiler/dart_compiler.dart';
import 'package:refractor/src/engine/kernel/file_kernel_io.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/passes/opaque_predicate/config/opaque_predicate_config.dart';
import 'package:refractor/src/engine/passes/opaque_predicate/opaque_predicate_pass.dart';
import 'package:refractor/src/policy/keep_policy.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';
import 'package:refractor/src/project/project_scope.dart';
import 'package:test/test.dart';

class _VariableGetCollector extends RecursiveVisitor {
  final Set<VariableDeclaration> found = {};

  @override
  void visitVariableGet(VariableGet node) {
    found.add(node.variable);
    super.visitVariableGet(node);
  }
}

void main() {
  group('OpaquePredicatePass (live variable)', () {
    late Directory dir;
    final Compiler compiler = DartCompiler();
    final io = FileKernelIO();

    setUp(() => dir = Directory.systemTemp.createTempSync('opl_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    test(
      'entangles the predicate with an int parameter',
      () async {
        final root = dir.resolveSymbolicLinksSync();
        final appDart = '$root/app.dart';
        final appDill = '$root/app.dill';
        File(appDart).writeAsStringSync('''
int classify(int n) {
  if (n > 3) {
    return 1;
  }
  return 0;
}

void main() {
  print(classify(int.parse('5')));
  print(classify(int.parse('2')));
}
''');
        compiler.compileToKernel(appDart, appDill);
        final component = io.load(appDill);

        final scope = ObfuscationScope(
          project: ProjectScope(
            projectRootUri: Uri.directory(root),
            projectPackageName: null,
          ),
          keep: KeepPolicy.empty,
        );

        final result = await OpaquePredicatePass(
          config: const OpaquePredicatePassConfig(),
          scope: scope,
        ).run(component);

        expect(result, isA<PassSucceeded>());
        expect(result.report.metadata['conditions_strengthened'], '1');

        // The strengthened condition reads the function's int parameter, so the
        // predicate is data-dependent rather than a folded constant.
        final classify = component.mainMethod!.enclosingLibrary.procedures
            .firstWhere((procedure) => procedure.name.text == 'classify');
        final parameter = classify.function.positionalParameters.first;
        final ifStatement = (classify.function.body! as Block).statements
            .whereType<IfStatement>()
            .first;
        final collector = _VariableGetCollector();
        ifStatement.condition.accept(collector);
        expect(collector.found, contains(parameter));

        final outDill = '$root/out.dill';
        io.write(component, outDill);
        final exe = '$root/app_exe';
        compiler.compileToTarget(outDill, exe, Target.exe);

        final run = Process.runSync(exe, const []);
        expect(run.exitCode, 0, reason: '${run.stderr}');
        expect(
          run.stdout
              .toString()
              .trim()
              .split('\n')
              .map((l) => l.trim())
              .toList(),
          ['1', '0'],
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
