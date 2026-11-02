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

int _reads(Expression expression, VariableDeclaration variable) {
  final collector = _VariableGetCounter(variable);
  expression.accept(collector);
  return collector.count;
}

class _VariableGetCounter extends RecursiveVisitor {
  _VariableGetCounter(this.variable);

  final VariableDeclaration variable;
  int count = 0;

  @override
  void visitVariableGet(VariableGet node) {
    if (node.variable == variable) {
      count++;
    }
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

        final result = OpaquePredicatePass(
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

    test(
      'entangles the predicate with a block-local variable',
      () async {
        final root = dir.resolveSymbolicLinksSync();
        final appDart = '$root/app.dart';
        final appDill = '$root/app.dill';
        File(appDart).writeAsStringSync('''
void main() {
  final seed = int.parse('5');
  if (seed > 3) {
    print('big');
  } else {
    print('small');
  }
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

        // The predicate reads the block-local `seed` declared before the `if`.
        final body = component.mainMethod!.function.body! as Block;
        final seed = body.statements.whereType<VariableDeclaration>().first;
        final ifStatement = body.statements.whereType<IfStatement>().first;
        final collector = _VariableGetCollector();
        ifStatement.condition.accept(collector);
        expect(collector.found, contains(seed));

        final outDill = '$root/out.dill';
        io.write(component, outDill);
        final exe = '$root/app_exe';
        compiler.compileToTarget(outDill, exe, Target.exe);

        final run = Process.runSync(exe, const []);
        expect(run.exitCode, 0, reason: '${run.stderr}');
        expect(run.stdout.toString().trim(), 'big');
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'never reads a nullable, late or unassigned int',
      () async {
        final root = dir.resolveSymbolicLinksSync();
        final appDart = '$root/app.dart';
        final appDill = '$root/app.dill';
        File(appDart).writeAsStringSync('''
int orZero(int? v) {
  if (v == null) return 0;
  return v;
}

int lateLocal(bool c) {
  late int z;
  if (c) z = 5;
  if (!c) return 0;
  return z;
}

int unassigned(bool c) {
  int y;
  if (c) {
    y = 1;
  } else {
    y = 2;
  }
  return y;
}

void main() {
  print(orZero(null));
  print(orZero(int.parse('7')));
  print(lateLocal(int.parse('0') == 1));
  print(lateLocal(int.parse('1') == 1));
  print(unassigned(int.parse('1') == 1));
  print(unassigned(int.parse('0') == 1));
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

        // No strengthened condition reads `v` (nullable), `z` (late) or `y`
        // (declared without an initializer) beyond what the source already did.
        final procedures = component.mainMethod!.enclosingLibrary.procedures;
        Procedure named(String name) =>
            procedures.firstWhere((procedure) => procedure.name.text == name);

        final orZero = named('orZero').function;
        final v = orZero.positionalParameters.first;
        final vCheck = (orZero.body! as Block).statements
            .whereType<IfStatement>()
            .first;
        expect(_reads(vCheck.condition, v), 1);

        for (final name in ['lateLocal', 'unassigned']) {
          final body = named(name).function.body! as Block;
          final local = body.statements.whereType<VariableDeclaration>().first;
          for (final site in body.statements.whereType<IfStatement>()) {
            expect(
              _reads(site.condition, local),
              0,
              reason: '$name must not read ${local.name} in a condition',
            );
          }
        }

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
          ['0', '7', '0', '5', '1', '2'],
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
