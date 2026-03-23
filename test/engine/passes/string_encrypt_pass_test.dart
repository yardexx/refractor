import 'dart:convert';

import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/obfuscation_target.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/passes/string_encrypt/string_encrypt_pass.dart';
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
    late ObfuscationTarget target;

    setUp(() {
      coreLib = makeDartCoreLibrary();
      userLib = makeUserLibrary();
      target = makeObfuscationTarget();
    });

    test(
      'string literal in procedure body is replaced with StaticInvocation',
      () async {
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
        await StringEncryptPass().run(component, target);

        final body = proc.function.body! as Block;
        final ret = body.statements.first as ReturnStatement;
        expect(ret.expression, isA<StaticInvocation>());
      },
    );

    test('string literal inside ConstantExpression is NOT replaced', () async {
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
      await StringEncryptPass().run(component, target);

      final body = proc.function.body! as Block;
      final ret = body.statements.first as ReturnStatement;
      expect(ret.expression, isA<ConstantExpression>());
    });

    test('string literal in class annotation is NOT replaced', () async {
      final cls = Class(name: 'Annotated', fileUri: userLib.fileUri)
        ..addAnnotation(ConstantExpression(StringConstant('keep_me')));
      userLib.addClass(cls);

      component = makeComponent(coreLib: coreLib, userLib: userLib);
      await StringEncryptPass().run(component, target);

      final annotation = cls.annotations.first as ConstantExpression;
      expect(annotation.constant, isA<StringConstant>());
      expect((annotation.constant as StringConstant).value, equals('keep_me'));
    });

    test(
      'non-const expression in class annotation is NOT replaced',
      () async {
        final cls = Class(name: 'Annotated', fileUri: userLib.fileUri)
          ..addAnnotation(StringLiteral('keep_expr'));
        userLib.addClass(cls);

        component = makeComponent(coreLib: coreLib, userLib: userLib);
        await StringEncryptPass().run(component, target);

        final annotation = cls.annotations.first;
        expect(annotation, isA<StringLiteral>());
        expect((annotation as StringLiteral).value, equals('keep_expr'));
      },
    );

    test('string literal in field annotation is NOT replaced', () async {
      final field = Field.mutable(
        Name('flag'),
        fileUri: userLib.fileUri,
      )..addAnnotation(ConstantExpression(StringConstant('keep_field')));
      userLib.addField(field);

      component = makeComponent(coreLib: coreLib, userLib: userLib);
      await StringEncryptPass().run(component, target);

      final annotation = field.annotations.first as ConstantExpression;
      expect(annotation.constant, isA<StringConstant>());
      expect(
        (annotation.constant as StringConstant).value,
        equals('keep_field'),
      );
    });

    test('string literal in constructor annotation is NOT replaced', () async {
      final cls = Class(name: 'Factory', fileUri: userLib.fileUri);
      final constructor = Constructor(
        FunctionNode(EmptyStatement()),
        name: Name(''),
        fileUri: userLib.fileUri,
      )..addAnnotation(ConstantExpression(StringConstant('keep_ctor')));
      cls.addConstructor(constructor);
      userLib.addClass(cls);

      component = makeComponent(coreLib: coreLib, userLib: userLib);
      await StringEncryptPass().run(component, target);

      final annotation = constructor.annotations.first as ConstantExpression;
      expect(annotation.constant, isA<StringConstant>());
      expect(
        (annotation.constant as StringConstant).value,
        equals('keep_ctor'),
      );
    });

    test('stringExcludePatterns exempts matching strings', () async {
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
      await StringEncryptPass(
        excludePatterns: [RegExp('DO_NOT_ENCRYPT')],
      ).run(component, target);

      final body = proc.function.body! as Block;
      final ret = body.statements.first as ReturnStatement;
      expect(ret.expression, isA<StringLiteral>());
      expect((ret.expression! as StringLiteral).value, 'DO_NOT_ENCRYPT');
    });

    test('no user library means pass is a no-op', () async {
      // Component with only core lib — no crash.
      final comp = Component(libraries: [coreLib])
        ..setMainMethodAndMode(null, true);
      final result = await StringEncryptPass().run(comp, target);

      expect(comp.libraries.length, equals(1));
      expect(result, isA<PassSucceeded>());
      expect(result.report.isEmpty, isTrue);
    });

    test(r'helper _obfDecode$ is injected into first user library', () async {
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
      await StringEncryptPass().run(component, target);

      final helperNames = userLib.procedures.map((p) => p.name.text).toList();
      expect(helperNames, contains(r'_obfDecode$'));
    });

    test(
      r'helper injection avoids collisions with existing _obfDecode$',
      () async {
        userLib.addProcedure(
          Procedure(
            Name(r'_obfDecode$', userLib),
            ProcedureKind.Method,
            FunctionNode(EmptyStatement()),
            fileUri: userLib.fileUri,
            isStatic: true,
          ),
        );
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
        await StringEncryptPass().run(component, target);

        final helperNames = userLib.procedures.map((p) => p.name.text).toList();
        expect(helperNames, contains(r'_obfDecode$'));
        expect(helperNames, contains(r'_obfDecode$1'));
      },
    );

    test('dart: library strings are not encrypted', () async {
      final coreProc = Procedure(
        Name('coreHelper'),
        ProcedureKind.Method,
        FunctionNode(
          Block([ReturnStatement(StringLiteral('sdk_string'))]),
        ),
        fileUri: coreLib.fileUri,
      );
      coreLib.addProcedure(coreProc);

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
      await StringEncryptPass().run(component, target);

      final coreBody = coreProc.function.body! as Block;
      final coreRet = coreBody.statements.first as ReturnStatement;
      expect(coreRet.expression, isA<StringLiteral>());
    });

    test('uses per-string keys instead of one fixed key', () async {
      final proc = Procedure(
        Name('keys'),
        ProcedureKind.Method,
        FunctionNode(
          Block([
            ExpressionStatement(StringLiteral('first')),
            ReturnStatement(StringLiteral('second')),
          ]),
        ),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(proc);

      component = makeComponent(coreLib: coreLib, userLib: userLib);
      await StringEncryptPass().run(component, target);

      final body = proc.function.body! as Block;
      final firstExpr = body.statements[0] as ExpressionStatement;
      final secondRet = body.statements[1] as ReturnStatement;
      final firstCall = firstExpr.expression as StaticInvocation;
      final secondCall = secondRet.expression! as StaticInvocation;
      final firstKey = firstCall.arguments.positional[1] as IntLiteral;
      final secondKey = secondCall.arguments.positional[1] as IntLiteral;

      expect(firstKey.value, isNot(equals(secondKey.value)));
    });

    test('returns report with encrypted string count', () async {
      final proc = Procedure(
        Name('counted'),
        ProcedureKind.Method,
        FunctionNode(
          Block([ReturnStatement(StringLiteral('hello'))]),
        ),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(proc);

      component = makeComponent(coreLib: coreLib, userLib: userLib);
      final result = await StringEncryptPass().run(component, target);

      expect(result, isA<PassSucceeded>());
      expect(result.report.passName, 'string_encrypt');
      expect(result.report.metrics.single.key, 'strings_encrypted');
      expect(result.report.metrics.single.value, 1);
    });
  });
}
