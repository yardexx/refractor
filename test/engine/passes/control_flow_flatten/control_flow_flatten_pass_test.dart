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

        final scope = ObfuscationScope(
          project: ProjectScope(
            projectRootUri: Uri.directory(root),
            projectPackageName: null,
          ),
          keep: KeepPolicy.empty,
        );

        final result = await ControlFlowFlattenPass(
          config: const ControlFlowFlattenPassConfig(),
          scope: scope,
        ).run(component);

        expect(result, isA<PassSucceeded>());
        expect(result.report.metadata['functions_flattened'], '1');
        // The body is now a switch-dispatch state machine, not a plain block.
        expect(component.mainMethod!.function.body, isA<LabeledStatement>());

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
          ['1', '2', '3', '4'],
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
