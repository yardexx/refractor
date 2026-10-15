@Tags(['integration'])
library;

import 'dart:io';

import 'package:kernel/ast.dart';
import 'package:kernel/core_types.dart';
import 'package:refractor/src/engine/compiler/compiler.dart';
import 'package:refractor/src/engine/compiler/dart_compiler.dart';
import 'package:refractor/src/engine/kernel/file_kernel_io.dart';
import 'package:refractor/src/engine/kernel/source_helper_injector.dart';
import 'package:refractor/src/engine/passes/string_encrypt/runtime/decode_runtime.dart';
import 'package:test/test.dart';

/// Inverse of the injected helper, used to embed valid encoded bytes.
List<int> _encode(String value, int key) {
  final out = <int>[];
  var shift = 0;
  for (final byte in value.codeUnits) {
    out.add(byte ^ ((key >> shift) & 0xFF));
    shift = (shift + 8) & 24;
  }
  return out.reversed.toList();
}

/// Replaces the literal `'REPLACE_ME'` with a call to the injected helper.
class _CallRewriter extends Transformer {
  _CallRewriter(this.decode, this.intType);

  final Procedure decode;
  final DartType intType;

  @override
  TreeNode visitStringLiteral(StringLiteral node) {
    if (node.value != 'REPLACE_ME') return node;
    final bytes = _encode('hello', 90);
    return StaticInvocation(
      decode,
      Arguments([
        ListLiteral(
          bytes.map((b) => IntLiteral(b) as Expression).toList(),
          typeArgument: intType,
        ),
        IntLiteral(90),
      ]),
    );
  }
}

void main() {
  group('SourceHelperInjector', () {
    late Directory dir;
    final Compiler compiler = DartCompiler();
    final io = FileKernelIO();

    setUp(() => dir = Directory.systemTemp.createTempSync('she_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    test(
      'reparents the helper and the AOT program runs it',
      () {
        final appDart = '${dir.path}/app.dart';
        final appDill = '${dir.path}/app.dill';
        File(appDart).writeAsStringSync("void main() { print('REPLACE_ME'); }");
        compiler.compileToKernel(appDart, appDill);
        final component = io.load(appDill);

        final target = component.mainMethod!.enclosingLibrary;
        int coreCount() => component.libraries
            .where((l) => '${l.importUri}' == 'dart:core')
            .length;
        final coreBefore = coreCount();

        final reparented = SourceHelperInjector(compiler: compiler).inject(
          component,
          const HelperSource(
            source: decodeRuntimeSource,
            procedureNames: {decodeRuntimeHelperName},
          ),
          targetLibrary: target,
        );

        // Helper is present, lives in an existing program library, and no
        // standalone helper library or duplicate SDK remains.
        expect(reparented.keys, contains(decodeRuntimeHelperName));
        final decode = reparented[decodeRuntimeHelperName]!;
        expect(decode.enclosingLibrary, same(target));
        expect(coreCount(), coreBefore);
        expect(
          component.libraries.map((l) => '${l.importUri}'),
          isNot(contains(contains('helper.dart'))),
        );

        // Rewrite the plaintext to call the helper, then AOT-compile and run.
        final intType = CoreTypes(component).intNonNullableRawType;
        component.transformChildren(_CallRewriter(decode, intType));

        final mergedDill = '${dir.path}/merged.dill';
        io.write(component, mergedDill);
        final exe = '${dir.path}/app_exe';
        compiler.compileToTarget(mergedDill, exe, Target.exe);

        final result = Process.runSync(exe, const []);
        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect(result.stdout.toString().trim(), 'hello');
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
