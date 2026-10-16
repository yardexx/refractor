@Tags(['integration'])
library;

import 'dart:io';

import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/compiler/compiler.dart';
import 'package:refractor/src/engine/compiler/dart_compiler.dart';
import 'package:refractor/src/engine/kernel/file_kernel_io.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/passes/bogus_control_flow/bogus_control_flow_pass.dart';
import 'package:refractor/src/engine/passes/bogus_control_flow/config/bogus_control_flow_config.dart';
import 'package:refractor/src/policy/keep_policy.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';
import 'package:refractor/src/project/project_scope.dart';
import 'package:test/test.dart';

void main() {
  group('BogusControlFlowPass', () {
    late Directory dir;
    final Compiler compiler = DartCompiler();
    final io = FileKernelIO();

    setUp(() => dir = Directory.systemTemp.createTempSync('bcf_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    test(
      'wraps a body in a bogus branch; AOT behaviour is unchanged',
      () async {
        final root = dir.resolveSymbolicLinksSync();
        final appDart = '$root/app.dart';
        final appDill = '$root/app.dill';
        // `compute` has an int parameter and a multi-statement block body with
        // locals and a return, so the whole body is cloned into the bogus
        // branch (exercising variable remapping in the clone).
        File(appDart).writeAsStringSync('''
int compute(int seed) {
  final a = seed * 3;
  final b = a + 7;
  return b - 2;
}

void main() {
  print(compute(10));
  print(compute(4));
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

        final result = await BogusControlFlowPass(
          config: const BogusControlFlowPassConfig(),
          scope: scope,
        ).run(component);

        expect(result, isA<PassSucceeded>());
        // Only `compute` has an int parameter; `main` does not.
        expect(result.report.metadata['bogus_branches_inserted'], '1');

        // compute's body now opens with the guarded if, which has a real
        // else-branch (the clone), not a plain block.
        final compute = component.mainMethod!.enclosingLibrary.procedures
            .firstWhere((procedure) => procedure.name.text == 'compute');
        final first = (compute.function.body! as Block).statements.first;
        expect(first, isA<IfStatement>());
        expect((first as IfStatement).otherwise, isNotNull);

        final outDill = '$root/out.dill';
        io.write(component, outDill);
        final exe = '$root/app_exe';
        compiler.compileToTarget(outDill, exe, Target.exe);

        final run = Process.runSync(exe, const []);
        expect(run.exitCode, 0, reason: '${run.stderr}');
        // seed=10: 10*3=30, +7=37, -2=35 ; seed=4: 12,19,17
        expect(
          run.stdout
              .toString()
              .trim()
              .split('\n')
              .map((l) => l.trim())
              .toList(),
          ['35', '17'],
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
