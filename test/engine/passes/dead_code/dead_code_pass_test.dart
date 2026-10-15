@Tags(['integration'])
library;

import 'dart:io';

import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/compiler/compiler.dart';
import 'package:refractor/src/engine/compiler/dart_compiler.dart';
import 'package:refractor/src/engine/kernel/file_kernel_io.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/passes/dead_code/config/dead_code_config.dart';
import 'package:refractor/src/engine/passes/dead_code/dead_code_pass.dart';
import 'package:refractor/src/policy/keep_policy.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';
import 'package:refractor/src/project/project_scope.dart';
import 'package:test/test.dart';

void main() {
  group('DeadCodePass', () {
    late Directory dir;
    final Compiler compiler = DartCompiler();
    final io = FileKernelIO();

    setUp(() => dir = Directory.systemTemp.createTempSync('dc_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    test(
      'inserts a guarded dead block; AOT behaviour is unchanged',
      () async {
        final root = dir.resolveSymbolicLinksSync();
        final appDart = '$root/app.dart';
        final appDill = '$root/app.dill';
        File(appDart).writeAsStringSync('''
int addOne(int p) {
  return p + 1;
}

void main() {
  print(addOne(int.parse('5')));
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

        final result = await DeadCodePass(
          config: const DeadCodePassConfig(),
          scope: scope,
        ).run(component);

        expect(result, isA<PassSucceeded>());
        expect(result.report.metadata['blocks_inserted'], '1');

        // The body now opens with the guarded dead block.
        final addOne = component.mainMethod!.enclosingLibrary.procedures
            .firstWhere((procedure) => procedure.name.text == 'addOne');
        final firstStatement =
            (addOne.function.body! as Block).statements.first;
        expect(firstStatement, isA<IfStatement>());

        final outDill = '$root/out.dill';
        io.write(component, outDill);
        final exe = '$root/app_exe';
        compiler.compileToTarget(outDill, exe, Target.exe);

        final run = Process.runSync(exe, const []);
        expect(run.exitCode, 0, reason: '${run.stderr}');
        expect(run.stdout.toString().trim(), '6');
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
