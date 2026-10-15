@Tags(['integration'])
library;

import 'dart:io';

import 'package:refractor/src/engine/compiler/compiler.dart';
import 'package:refractor/src/engine/compiler/dart_compiler.dart';
import 'package:refractor/src/engine/kernel/file_kernel_io.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/passes/arithmetic_mangle/arithmetic_mangle_pass.dart';
import 'package:refractor/src/engine/passes/arithmetic_mangle/config/arithmetic_mangle_config.dart';
import 'package:refractor/src/policy/keep_policy.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';
import 'package:refractor/src/project/project_scope.dart';
import 'package:test/test.dart';

void main() {
  group('ArithmeticManglePass', () {
    late Directory dir;
    final Compiler compiler = DartCompiler();
    final io = FileKernelIO();

    setUp(() => dir = Directory.systemTemp.createTempSync('am_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    test(
      'mangles nested int +/*; side effects fire exactly once',
      () async {
        final root = dir.resolveSymbolicLinksSync();
        final appDart = '$root/app.dart';
        final appDill = '$root/app.dill';
        // `tap` records every call. The result (23) and the accumulated side
        // value (3+4+5=12) only hold if each operand is evaluated exactly once
        // and in order, which the Let-bound temporaries must preserve.
        File(appDart).writeAsStringSync(r'''
int side = 0;
int tap(int v) {
  side = side + v;
  return v;
}

void main() {
  final r = tap(3) + tap(4) * tap(5);
  print('$r,$side');
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

        final result = await ArithmeticManglePass(
          config: const ArithmeticManglePassConfig(),
          scope: scope,
        ).run(component);

        expect(result, isA<PassSucceeded>());
        final mangled = int.parse(
          result.report.metadata['operations_mangled']!,
        );
        expect(mangled, greaterThanOrEqualTo(2));

        final outDill = '$root/out.dill';
        io.write(component, outDill);
        final exe = '$root/app_exe';
        compiler.compileToTarget(outDill, exe, Target.exe);

        final run = Process.runSync(exe, const []);
        expect(run.exitCode, 0, reason: '${run.stderr}');
        expect(run.stdout.toString().trim(), '23,12');
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
