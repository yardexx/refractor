@Tags(['integration'])
library;

import 'dart:io';

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

void main() {
  group('OpaquePredicatePass', () {
    late Directory dir;
    final Compiler compiler = DartCompiler();
    final io = FileKernelIO();

    setUp(() => dir = Directory.systemTemp.createTempSync('op_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    test(
      'strengthens conditions; AOT behaviour is unchanged',
      () async {
        // Resolve symlinks so the project root matches the kernel's file URIs
        // (macOS temp dirs are /var -> /private/var).
        final root = dir.resolveSymbolicLinksSync();
        final appDart = '$root/app.dart';
        final appDill = '$root/app.dill';
        File(appDart).writeAsStringSync('''
void main() {
  final x = int.parse('5');
  final y = int.parse('2');
  var total = 0;
  if (x > 3) {
    total += 10;
  } else {
    total += 1;
  }
  if (y > 3) {
    total += 100;
  } else {
    total += 2;
  }
  print(total);
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

        final result = OpaquePredicatePass(
          config: const OpaquePredicatePassConfig(),
          scope: scope,
        ).run(component);

        expect(result, isA<PassSucceeded>());
        expect(result.report.metadata['conditions_strengthened'], '2');

        final outDill = '$root/out.dill';
        io.write(component, outDill);
        final exe = '$root/app_exe';
        compiler.compileToTarget(outDill, exe, Target.exe);

        final run = Process.runSync(exe, const []);
        expect(run.exitCode, 0, reason: '${run.stderr}');
        expect(run.stdout.toString().trim(), '12');
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
