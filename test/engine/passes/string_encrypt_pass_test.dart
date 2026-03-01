import 'dart:convert';

import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/passes/string_encrypt/string_encrypt_pass.dart';
import 'package:refractor/src/engine/runner/pass_options.dart';
import 'package:test/test.dart';

import '../../helpers/kernel_helpers.dart';

void main() {
  group('StringEncryptPass.encode', () {
    test('round-trip XOR with known key', () {
      final pass = StringEncryptPass();
      const input = 'hello';
      final encoded = pass.encode(input);

      // Decode by XOR-ing again with the same key.
      final decoded = utf8.decode(encoded.map((b) => b ^ 0x5A).toList());
      expect(decoded, equals(input));
    });

    test('with custom xorKey', () {
      final pass = StringEncryptPass(xorKey: 0xFF);
      const input = 'abc';
      final encoded = pass.encode(input);

      final decoded = utf8.decode(encoded.map((b) => b ^ 0xFF).toList());
      expect(decoded, equals(input));
    });

    test('with empty string', () {
      final pass = StringEncryptPass();
      final encoded = pass.encode('');
      expect(encoded, isEmpty);
    });
  });

  group('StringEncryptPass.run', () {
    late Library coreLib;
    late Library userLib;
    late Component component;

    setUp(() {
      coreLib = makeDartCoreLibrary();
      userLib = makeUserLibrary();
    });

    test('string literal in procedure body is replaced with StaticInvocation',
        () {
      final proc = Procedure(
        Name('greet'),
        ProcedureKind.Method,
        FunctionNode(
          Block([
            ReturnStatement(StringLiteral('hello')),
          ]),
        ),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(proc);

      component = makeComponent(coreLib: coreLib, userLib: userLib);
      final context = makePassContext();
      StringEncryptPass().run(component, context);

      final body = proc.function.body! as Block;
      final ret = body.statements.first as ReturnStatement;
      expect(ret.expression, isA<StaticInvocation>());
    });

    test('string literal inside ConstantExpression is NOT replaced', () {
      // Create a ConstantExpression wrapping a string — the pass should skip.
      final constExpr = ConstantExpression(StringConstant('keep'));
      final proc = Procedure(
        Name('constTest'),
        ProcedureKind.Method,
        FunctionNode(
          Block([
            ReturnStatement(constExpr),
          ]),
        ),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(proc);

      component = makeComponent(coreLib: coreLib, userLib: userLib);
      final context = makePassContext();
      StringEncryptPass().run(component, context);

      final body = proc.function.body! as Block;
      final ret = body.statements.first as ReturnStatement;
      expect(ret.expression, isA<ConstantExpression>());
    });

    test('string literal in class annotation is NOT replaced', () {
      final cls = Class(name: 'Annotated', fileUri: userLib.fileUri)
        ..addAnnotation(ConstantExpression(StringConstant('keep_me')));
      userLib.addClass(cls);

      component = makeComponent(coreLib: coreLib, userLib: userLib);
      final context = makePassContext();
      StringEncryptPass().run(component, context);

      final annotation = cls.annotations.first as ConstantExpression;
      expect(annotation.constant, isA<StringConstant>());
      expect((annotation.constant as StringConstant).value, equals('keep_me'));
    });

    test('stringExcludePatterns exempts matching strings', () {
      final proc = Procedure(
        Name('exempt'),
        ProcedureKind.Method,
        FunctionNode(
          Block([
            ReturnStatement(StringLiteral('DO_NOT_ENCRYPT')),
          ]),
        ),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(proc);

      component = makeComponent(coreLib: coreLib, userLib: userLib);
      final context = makePassContext(
        PassOptions(stringExcludePatterns: [RegExp('DO_NOT_ENCRYPT')]),
      );
      StringEncryptPass().run(component, context);

      final body = proc.function.body! as Block;
      final ret = body.statements.first as ReturnStatement;
      expect(ret.expression, isA<StringLiteral>());
      expect((ret.expression! as StringLiteral).value, 'DO_NOT_ENCRYPT');
    });

    test('no user library means pass is a no-op', () {
      // Component with only core lib — no crash.
      final comp = Component(libraries: [coreLib])
        ..setMainMethodAndMode(null, true);
      final context = makePassContext();
      StringEncryptPass().run(comp, context);

      expect(comp.libraries.length, equals(1));
    });

    test(r'helper _obfDecode$ is injected into first user library', () {
      final proc = Procedure(
        Name('fn'),
        ProcedureKind.Method,
        FunctionNode(
          Block([ReturnStatement(StringLiteral('test'))]),
        ),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(proc);

      component = makeComponent(coreLib: coreLib, userLib: userLib);
      final context = makePassContext();
      StringEncryptPass().run(component, context);

      final helperNames = userLib.procedures.map((p) => p.name.text).toList();
      expect(helperNames, contains(r'_obfDecode$'));
    });

    test('dart: library strings are not encrypted', () {
      // Add a string literal to a procedure in the core lib.
      final coreProc = Procedure(
        Name('coreHelper'),
        ProcedureKind.Method,
        FunctionNode(
          Block([ReturnStatement(StringLiteral('sdk_string'))]),
        ),
        fileUri: coreLib.fileUri,
      );
      coreLib.addProcedure(coreProc);

      // Also add a user proc so the pass has something to inject into.
      final userProc = Procedure(
        Name('userFn'),
        ProcedureKind.Method,
        FunctionNode(
          Block([ReturnStatement(StringLiteral('user_string'))]),
        ),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(userProc);

      component = makeComponent(coreLib: coreLib, userLib: userLib);
      final context = makePassContext();
      StringEncryptPass().run(component, context);

      // The core proc body should still be a StringLiteral.
      final coreBody = coreProc.function.body! as Block;
      final coreRet = coreBody.statements.first as ReturnStatement;
      expect(coreRet.expression, isA<StringLiteral>());
    });
  });
}
