@Tags(['integration'])
library;

import 'dart:convert';
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

        expect(result, isA<PassSucceeded>(), reason: result.report.message);
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

    test(
      'guards on a block-local int when there is no int parameter',
      () async {
        final root = dir.resolveSymbolicLinksSync();
        final appDart = '$root/app.dart';
        final appDill = '$root/app.dill';
        // `compute` takes no int parameter, so the guard must key off a
        // definitely-assigned int local; the dead block lands after a
        // declaration, not at index 0. `int.parse` keeps the local runtime so
        // the guard is not folded away.
        File(appDart).writeAsStringSync('''
int compute() {
  final seed = int.parse('5');
  final result = seed * 2 + 1;
  return result;
}

void main() {
  print(compute());
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

        expect(result, isA<PassSucceeded>(), reason: result.report.message);
        expect(result.report.metadata['blocks_inserted'], '1');

        final compute = component.mainMethod!.enclosingLibrary.procedures
            .firstWhere((procedure) => procedure.name.text == 'compute');
        final statements = (compute.function.body! as Block).statements;
        // The guard is inserted after a local declaration, not at the top.
        expect(statements.first, isNot(isA<IfStatement>()));
        expect(statements.any((s) => s is IfStatement), isTrue);

        final outDill = '$root/out.dill';
        io.write(component, outDill);
        final exe = '$root/app_exe';
        compiler.compileToTarget(outDill, exe, Target.exe);

        final run = Process.runSync(exe, const []);
        expect(run.exitCode, 0, reason: '${run.stderr}');
        expect(run.stdout.toString().trim(), '11');
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'dead blocks survive AOT compilation into machine code',
      () async {
        final root = dir.resolveSymbolicLinksSync();
        final appDart = '$root/app.dart';
        final appDill = '$root/app.dill';
        // Never-inlined, so each function keeps its own instruction count. The
        // three shapes between them allow every sink: `r*` return an int,
        // `w*` read their parameter after the block (reassign), `f*` key off
        // a final local (return or throw only).
        const noInline = "@pragma('vm:never-inline')";
        String r(int k) =>
            '$noInline int r$k(int a, int b) { var t = a * ${k + 3} + b; '
            'if (t > $k) { t ^= b; } return t; }';
        String w(int k) =>
            '$noInline void w$k(int a, List<int> out) { '
            'out.add(a * ${k + 2}); }';
        String f(int k) =>
            '$noInline int f$k(String s) { final n = s.length + $k; '
            'return n * n; }';
        final functions = [
          for (var k = 0; k < 4; k++) ...[r(k), w(k), f(k)],
        ];
        final names = [
          for (var k = 0; k < 4; k++) ...['r$k', 'w$k', 'f$k'],
        ];
        File(appDart).writeAsStringSync('''
${functions.join('\n')}

void main(List<String> args) {
  final out = <int>[];
  var acc = 0;
  final s = 'x' * int.parse('7');
  for (var i = 0; i < 50; i++) {
    acc += r0(i, acc & 255) + r1(i, acc & 255) + r2(i, acc & 255) + r3(i, acc & 255);
    w0(i, out); w1(i, out); w2(i, out); w3(i, out);
    acc += f0(s) + f1(s) + f2(s) + f3(s);
  }
  print('\$acc \${out.fold<int>(0, (p, e) => p ^ e)}');
}
''');
        compiler.compileToKernel(appDart, appDill);
        final baseline = _instructionSizes(appDill, '$root/base', names);

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
        expect(result, isA<PassSucceeded>(), reason: result.report.message);
        // One per function, plus one in `main` (keyed off `acc`).
        expect(
          result.report.metadata['blocks_inserted'],
          '${names.length + 1}',
        );

        // Every sink kind is exercised, so each is shown to survive.
        final sinks = <Type>{};
        for (final procedure
            in component.mainMethod!.enclosingLibrary.procedures) {
          if (!names.contains(procedure.name.text)) continue;
          final guarded = (procedure.function.body! as Block).statements
              .whereType<IfStatement>()
              .first;
          final last = (guarded.then as Block).statements.last;
          sinks.add(
            last is ExpressionStatement
                ? last.expression.runtimeType
                : last.runtimeType,
          );
        }
        expect(sinks, {VariableSet, ReturnStatement, Throw});

        final outDill = '$root/out.dill';
        io.write(component, outDill);
        final obfuscated = _instructionSizes(outDill, '$root/obf', names);

        // Before refractor emitted junk with effects, the AOT compiler deleted
        // the whole block and these sizes were identical.
        for (final name in names) {
          expect(
            obfuscated[name],
            greaterThan(baseline[name]!),
            reason: '$name: dead block was optimised out of the AOT build',
          );
        }

        final exe = '$root/app_exe';
        compiler.compileToTarget(outDill, exe, Target.exe);
        final run = Process.runSync(exe, const []);
        expect(run.exitCode, 0, reason: '${run.stderr}');
        expect(run.stdout.toString().trim(), _expectedSurvivalOutput());
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}

/// The survival app's output, computed here rather than hard-coded so the
/// arithmetic stays readable.
String _expectedSurvivalOutput() {
  int r(int k, int a, int b) {
    var t = a * (k + 3) + b;
    if (t > k) t ^= b;
    return t;
  }

  int f(int k, String s) => (s.length + k) * (s.length + k);

  final out = <int>[];
  var acc = 0;
  final s = 'x' * 7;
  for (var i = 0; i < 50; i++) {
    var sum = 0;
    for (var k = 0; k < 4; k++) {
      sum += r(k, i, acc & 255);
    }
    acc += sum;
    for (var k = 0; k < 4; k++) {
      out.add(i * (k + 2));
    }
    for (var k = 0; k < 4; k++) {
      acc += f(k, s);
    }
  }
  return '$acc ${out.fold<int>(0, (p, e) => p ^ e)}';
}

/// AOT-compiles [dill] and returns the machine-code size in bytes of each of
/// the top-level functions [names], read from gen_snapshot's per-function
/// instruction-size dump.
Map<String, int> _instructionSizes(
  String dill,
  String prefix,
  List<String> names,
) {
  final sizesJson = '$prefix.sizes.json';
  final compile = Process.runSync('dart', [
    'compile',
    'aot-snapshot',
    dill,
    '-o',
    '$prefix.aot',
    '--extra-gen-snapshot-options=--print-instructions-sizes-to=$sizesJson',
  ]);
  expect(compile.exitCode, 0, reason: '${compile.stdout}${compile.stderr}');

  final entries = (jsonDecode(File(sizesJson).readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  return {
    for (final name in names)
      name: entries
          .where(
            (e) =>
                (e['l'] as String? ?? '').endsWith('/app.dart') &&
                e['c'] == '' &&
                e['n'] == '[Optimized] $name',
          )
          .map((e) => e['s'] as int)
          .single,
  };
}
