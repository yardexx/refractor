import 'package:kernel/kernel.dart';
import 'package:refractor/src/config/model/refractor_config.dart';
import 'package:refractor/src/engine/kernel/runtime_helpers.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/passes/string_encrypt/config/string_encrypt_definition.dart';
import 'package:refractor/src/engine/passes/string_encrypt/reporting/string_encrypt_artifact.dart';
import 'package:refractor/src/engine/passes/string_encrypt/runtime/decode_runtime.dart';
import 'package:refractor/src/engine/passes/string_encrypt/string_encrypt_codec.dart';
import 'package:refractor/src/engine/passes/string_encrypt/string_encrypt_pass.dart';
import 'package:refractor/src/policy/keep_resolver.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';
import 'package:refractor/src/project/project_scope.dart';
import 'package:test/test.dart';

import '../../helpers/kernel_helpers.dart';

void main() {
  group('StringEncryptCodec.encodeWithKey', () {
    test('round-trips ASCII with known key', () {
      const input = 'hello';
      final encoded = StringEncryptCodec.encodeWithKey(input, 0x5A);
      final decoded = StringEncryptCodec.decodeWithKey(encoded, 0x5A);
      expect(decoded, equals(input));
    });

    test('with custom key', () {
      const input = 'abc';
      final encoded = StringEncryptCodec.encodeWithKey(input, 0xFF);
      final decoded = StringEncryptCodec.decodeWithKey(encoded, 0xFF);
      expect(decoded, equals(input));
    });

    test('with empty string', () {
      final encoded = StringEncryptCodec.encodeWithKey('', 0x5A);
      expect(encoded, isEmpty);
    });

    test('round-trips Unicode with multi-byte UTF-8', () {
      const input = 'žluťoučký 🌍';
      final encoded = StringEncryptCodec.encodeWithKey(input, 0x12345678);

      expect(
        StringEncryptCodec.decodeWithKey(encoded, 0x12345678),
        equals(input),
      );
    });
  });

  group('StringEncryptPass.run', () {
    late Library coreLib;
    late Library convertLib;
    late Library userLib;
    late Component component;
    late ProjectScope projectScope;

    late RuntimeHelpers helpers;

    setUp(() {
      helpers = RuntimeHelpers.none;
      coreLib = makeDartCoreLibrary();
      convertLib = makeDartConvertLibrary();
      userLib = makeUserLibrary();
      projectScope = makeProjectScope();
    });

    Component makeRuntimeComponent() {
      final component = makeComponent(
        coreLib: coreLib,
        userLib: userLib,
        extraLibraries: [convertLib],
      );
      // In a real build the engine injects the decode helper before the pass
      // runs and hands it over as RuntimeHelpers. Supply a stand-in for these
      // unit tests so each rewritten literal has a procedure to call.
      helpers = RuntimeHelpers({
        decodeRuntimeHelperName: addDecodeHelperStandIn(
          coreLib: coreLib,
          userLib: userLib,
        ),
      });
      return component;
    }

    StringEncryptPass makePass(
      Component component, {
      StringEncryptPassConfig config = const StringEncryptPassConfig(),
    }) {
      final keepResolver = KeepResolver(
        component: component,
        projectScope: projectScope,
        globalExcludes: RefractorConfig(passes: [config]).excludePatterns,
      );
      return StringEncryptPass(
        config: config,
        helpers: helpers,
        scope: ObfuscationScope(
          project: projectScope,
          keep: keepResolver.resolve(
            const StringEncryptDefinition().keepSources,
            config.exclude,
          ),
        ),
      );
    }

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

        component = makeRuntimeComponent();
        await makePass(component).run(component);

        final body = proc.function.body! as Block;
        final ret = body.statements.first as ReturnStatement;
        expect(ret.expression, isA<StaticInvocation>());
      },
    );

    test('@Refractor.keep() class is exempt from string encryption', () async {
      final annotationLib = makeRefractorAnnotationLibrary();
      final keptString = StringLiteral('secret_in_kept_class');
      final cls = Class(name: 'Keeper', fileUri: userLib.fileUri)
        ..addAnnotation(makeRefractorKeepAnnotation(annotationLib));
      final method = Procedure(
        Name('run'),
        ProcedureKind.Method,
        FunctionNode(Block([ReturnStatement(keptString)])),
        fileUri: userLib.fileUri,
      );
      cls.addProcedure(method);
      userLib.addClass(cls);

      final comp = makeComponent(
        coreLib: coreLib,
        userLib: userLib,
        extraLibraries: [convertLib, annotationLib],
      );
      await makePass(comp).run(comp);

      final body = method.function.body! as Block;
      final ret = body.statements.first as ReturnStatement;
      expect(ret.expression, isA<StringLiteral>());
      expect((ret.expression! as StringLiteral).value, 'secret_in_kept_class');
    });

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

      component = makeRuntimeComponent();
      await makePass(component).run(component);

      final body = proc.function.body! as Block;
      final ret = body.statements.first as ReturnStatement;
      expect(ret.expression, isA<ConstantExpression>());
    });

    test('string literal in class annotation is NOT replaced', () async {
      final cls = Class(name: 'Annotated', fileUri: userLib.fileUri)
        ..addAnnotation(ConstantExpression(StringConstant('keep_me')));
      userLib.addClass(cls);

      component = makeRuntimeComponent();
      await makePass(component).run(component);

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

        component = makeRuntimeComponent();
        await makePass(component).run(component);

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

      component = makeRuntimeComponent();
      await makePass(component).run(component);

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

      component = makeRuntimeComponent();
      await makePass(component).run(component);

      final annotation = constructor.annotations.first as ConstantExpression;
      expect(annotation.constant, isA<StringConstant>());
      expect(
        (annotation.constant as StringConstant).value,
        equals('keep_ctor'),
      );
    });

    test('string literal in procedure annotation is NOT replaced', () async {
      final procedure = Procedure(
        Name('annotatedProcedure'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      )..addAnnotation(StringLiteral('keep_proc_annotation'));
      userLib.addProcedure(procedure);

      component = makeRuntimeComponent();
      await makePass(component).run(component);

      final annotation = procedure.annotations.first;
      expect(annotation, isA<StringLiteral>());
      expect(
        (annotation as StringLiteral).value,
        equals('keep_proc_annotation'),
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

      component = makeRuntimeComponent();
      await makePass(
        component,
        config: const StringEncryptPassConfig(
          excludePatterns: ['DO_NOT_ENCRYPT'],
        ),
      ).run(component);

      final body = proc.function.body! as Block;
      final ret = body.statements.first as ReturnStatement;
      expect(ret.expression, isA<StringLiteral>());
      expect((ret.expression! as StringLiteral).value, 'DO_NOT_ENCRYPT');
    });

    test('no user library means pass is a no-op', () async {
      // Component with only core lib — no crash.
      final comp = Component(libraries: [coreLib])
        ..setMainMethodAndMode(null, true);
      final result = await makePass(comp).run(comp);

      expect(comp.libraries.length, equals(1));
      expect(result, isA<PassSucceeded>());
      expect(result.report.isEmpty, isTrue);
      expect((result as PassSucceeded).artifact, isNull);
    });

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

      component = makeRuntimeComponent();
      await makePass(component).run(component);

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

      component = makeRuntimeComponent();
      await makePass(component).run(component);

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

      component = makeRuntimeComponent();
      final result = await makePass(component).run(component);

      expect(result, isA<PassSucceeded>());
      expect(result.report.passName, 'string_encrypt');
      expect(result.report.metadata['strings_encrypted'], '1');
    });

    test('returns string-encrypt artifact with applied record', () async {
      final proc = Procedure(
        Name('audit'),
        ProcedureKind.Method,
        FunctionNode(
          Block([ReturnStatement(StringLiteral('hello'))]),
        ),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(proc);

      component = makeRuntimeComponent();
      final result = await makePass(component).run(component);

      expect(result, isA<PassSucceeded>());
      final success = result as PassSucceeded;
      expect(success.artifact, isA<StringEncryptArtifact>());
      final artifact = success.artifact! as StringEncryptArtifact;

      expect(artifact.records, hasLength(1));
      final record = artifact.records.single;
      expect(record.plaintext, 'hello');
      expect(record.key, isNonZero);
      expect(
        record.encodedBytes,
        StringEncryptCodec.encodeWithKey('hello', record.key),
      );
      expect(record.libraryUri, userLib.importUri.toString());
      expect(record.enclosingMemberName, 'audit');
      expect(record.enclosingMemberKind, 'procedure');
      expect(record.fileUri, userLib.fileUri.toString());
    });

    test('artifact record count matches strings_encrypted metadata', () async {
      userLib.addProcedure(
        Procedure(
          Name('counted'),
          ProcedureKind.Method,
          FunctionNode(
            Block([
              ExpressionStatement(StringLiteral('first')),
              ReturnStatement(StringLiteral('second')),
            ]),
          ),
          fileUri: userLib.fileUri,
        ),
      );

      component = makeRuntimeComponent();
      final result = await makePass(component).run(component);
      final success = result as PassSucceeded;
      final artifact = success.artifact! as StringEncryptArtifact;

      expect(success.report.metadata['strings_encrypted'], '2');
      expect(artifact.records, hasLength(2));
    });

    test('artifact records member kind for field and constructor', () async {
      final field = Field.mutable(
        Name('stored'),
        initializer: StringLiteral('field_value'),
        fileUri: userLib.fileUri,
      );
      userLib.addField(field);

      final cls = Class(name: 'Factory', fileUri: userLib.fileUri);
      final constructor = Constructor(
        FunctionNode(
          Block([
            ExpressionStatement(StringLiteral('ctor_value')),
          ]),
        ),
        name: Name('named'),
        fileUri: userLib.fileUri,
      );
      cls.addConstructor(constructor);
      userLib.addClass(cls);

      component = makeRuntimeComponent();
      final result = await makePass(component).run(component);
      final artifact =
          (result as PassSucceeded).artifact! as StringEncryptArtifact;

      final fieldRecord = artifact.records.firstWhere(
        (record) => record.plaintext == 'field_value',
      );
      final constructorRecord = artifact.records.firstWhere(
        (record) => record.plaintext == 'ctor_value',
      );

      expect(fieldRecord.enclosingMemberName, 'stored');
      expect(fieldRecord.enclosingMemberKind, 'field');
      expect(constructorRecord.enclosingMemberName, 'named');
      expect(constructorRecord.enclosingMemberKind, 'constructor');
    });

    test('artifact excludes const, annotation, and excluded strings', () async {
      final procedure = Procedure(
        Name('mixed'),
        ProcedureKind.Method,
        FunctionNode(
          Block([
            ExpressionStatement(StringLiteral('keep_me')),
            ReturnStatement(ConstantExpression(StringConstant('const_value'))),
          ]),
        ),
        fileUri: userLib.fileUri,
      )..addAnnotation(StringLiteral('annotation_value'));
      userLib.addProcedure(procedure);

      component = makeRuntimeComponent();
      final result = await makePass(
        component,
        config: const StringEncryptPassConfig(
          excludePatterns: ['keep_me'],
        ),
      ).run(component);
      final success = result as PassSucceeded;

      expect(success.artifact, isNull);
      expect(success.report.metadata, isEmpty);
    });

    test('rewrites literal segments inside StringConcatenation', () async {
      final valueParam = VariableDeclaration('value');
      final procedure = Procedure(
        Name('greet'),
        ProcedureKind.Method,
        FunctionNode(
          ReturnStatement(
            StringConcatenation([
              StringLiteral('Hello '),
              VariableGet(valueParam),
              StringLiteral('!'),
            ]),
          ),
          positionalParameters: [valueParam],
          requiredParameterCount: 1,
        ),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(procedure);

      component = makeRuntimeComponent();
      final result = await makePass(component).run(component);

      expect(result, isA<PassSucceeded>());
      final returnStatement = procedure.function.body! as ReturnStatement;
      final concat = returnStatement.expression! as StringConcatenation;
      expect(concat.expressions[0], isA<StaticInvocation>());
      expect(concat.expressions[1], isA<VariableGet>());
      expect(concat.expressions[2], isA<StaticInvocation>());
      expect(result.report.metadata['strings_encrypted'], '2');
    });

    test('leaves empty StringConcatenation segments untouched', () async {
      final valueParam = VariableDeclaration('value');
      final procedure = Procedure(
        Name('greet'),
        ProcedureKind.Method,
        FunctionNode(
          ReturnStatement(
            StringConcatenation([
              StringLiteral(''),
              VariableGet(valueParam),
              StringLiteral('done'),
            ]),
          ),
          positionalParameters: [valueParam],
          requiredParameterCount: 1,
        ),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(procedure);

      component = makeRuntimeComponent();
      final result = await makePass(component).run(component);

      final returnStatement = procedure.function.body! as ReturnStatement;
      final concat = returnStatement.expression! as StringConcatenation;
      expect(concat.expressions[0], isA<StringLiteral>());
      expect((concat.expressions[0] as StringLiteral).value, isEmpty);
      expect(concat.expressions[2], isA<StaticInvocation>());
      expect(result.report.metadata['strings_encrypted'], '1');
    });
  });
}
