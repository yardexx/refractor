@Tags(['integration'])
library;

import 'dart:io';

import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/compiler/compiler.dart';
import 'package:refractor/src/engine/compiler/dart_compiler.dart';
import 'package:refractor/src/engine/kernel/file_kernel_io.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/passes/control_flow_flatten/config/control_flow_flatten_config.dart';
import 'package:refractor/src/engine/passes/control_flow_flatten/control_flow_flatten_pass.dart';
import 'package:refractor/src/policy/keep_policy.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';
import 'package:refractor/src/project/project_scope.dart';
import 'package:test/test.dart';

void main() {
  group('ControlFlowFlattenPass', () {
    late Directory dir;
    final Compiler compiler = DartCompiler();
    final io = FileKernelIO();

    setUp(() => dir = Directory.systemTemp.createTempSync('cff_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    ObfuscationScope scopeFor(String root) => ObfuscationScope(
      project: ProjectScope(
        projectRootUri: Uri.directory(root),
        projectPackageName: null,
      ),
      keep: KeepPolicy.empty,
    );

    List<String> buildRunAndCapture(String root, Component component) {
      final outDill = '$root/out.dill';
      io.write(component, outDill);
      final exe = '$root/app_exe';
      compiler.compileToTarget(outDill, exe, Target.exe);
      final run = Process.runSync(exe, const []);
      expect(run.exitCode, 0, reason: '${run.stderr}');
      return run.stdout
          .toString()
          .trim()
          .split('\n')
          .map((l) => l.trim())
          .toList();
    }

    test(
      'flattens a body; AOT keeps statement order',
      () async {
        final root = dir.resolveSymbolicLinksSync();
        final appDart = '$root/app.dart';
        final appDill = '$root/app.dill';
        File(appDart).writeAsStringSync('''
void main() {
  print('1');
  print('2');
  print('3');
  print('4');
}
''');
        compiler.compileToKernel(appDart, appDill);
        final component = io.load(appDill);

        final result = ControlFlowFlattenPass(
          config: const ControlFlowFlattenPassConfig(),
          scope: scopeFor(root),
        ).run(component);

        expect(result, isA<PassSucceeded>());
        expect(result.report.metadata['functions_flattened'], '1');
        // The body is now a switch-dispatch state machine, not a plain block.
        expect(component.mainMethod!.function.body, isA<LabeledStatement>());

        expect(buildRunAndCapture(root, component), ['1', '2', '3', '4']);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'carries local declarations and a return through the state machine',
      () async {
        final root = dir.resolveSymbolicLinksSync();
        final appDart = '$root/app.dart';
        final appDill = '$root/app.dill';
        // `compute` mixes an uninitialized declaration (hoisted to an empty
        // case), a later assignment, initialized declarations, an expression
        // statement, and a mid-body early return — so flattening must hoist
        // every local and let the return case exit the switch.
        File(appDart).writeAsStringSync(r'''
int compute(int seed) {
  int a;
  a = seed + 1;
  final b = a * 2;
  print('intermediate: $b');
  final c = b - 3;
  return a + b + c;
}

void main() {
  print(compute(4));
  print(compute(10));
}
''');
        compiler.compileToKernel(appDart, appDill);
        final component = io.load(appDill);

        final result = ControlFlowFlattenPass(
          config: const ControlFlowFlattenPassConfig(),
          scope: scopeFor(root),
        ).run(component);

        expect(result, isA<PassSucceeded>());
        // main (4 statements) and compute (5 statements) both flatten.
        expect(result.report.metadata['functions_flattened'], '2');

        // seed=4:  a=5,  b=10, c=7  -> 22
        // seed=10: a=11, b=22, c=19 -> 52
        expect(buildRunAndCapture(root, component), [
          'intermediate: 10',
          '22',
          'intermediate: 22',
          '52',
        ]);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
