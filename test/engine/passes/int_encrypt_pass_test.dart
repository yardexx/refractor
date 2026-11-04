import 'package:kernel/kernel.dart';
import 'package:refractor/src/config/model/refractor_config.dart';
import 'package:refractor/src/engine/kernel/runtime_helpers.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/passes/int_encrypt/config/int_encrypt_config.dart';
import 'package:refractor/src/engine/passes/int_encrypt/config/int_encrypt_definition.dart';
import 'package:refractor/src/engine/passes/int_encrypt/int_encrypt_pass.dart';
import 'package:refractor/src/engine/passes/int_encrypt/runtime/int_decode_runtime.dart';
import 'package:refractor/src/policy/keep_resolver.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';
import 'package:refractor/src/project/project_scope.dart';
import 'package:test/test.dart';

import '../../helpers/kernel_helpers.dart';

/// Recovers the original value from a decode call: `refractorDecodeInt`'s
/// arguments are `[encoded, key]`, and the encoding is `encoded ^ key`.
int _decodedValue(StaticInvocation call) {
  final encoded = (call.arguments.positional[0] as IntLiteral).value;
  final key = (call.arguments.positional[1] as IntLiteral).value;
  return encoded ^ key;
}

void main() {
  group('IntEncryptPass.run', () {
    late Library coreLib;
    late Library userLib;
    late Component component;
    late ProjectScope projectScope;

    late RuntimeHelpers helpers;

    setUp(() {
      helpers = RuntimeHelpers.none;
      coreLib = makeDartCoreLibrary();
      userLib = makeUserLibrary();
      projectScope = makeProjectScope();
    });

    Component makeRuntimeComponent() {
      final component = makeComponent(coreLib: coreLib, userLib: userLib);
      // In a real build the engine injects the decode helper before the pass
      // runs; supply a stand-in so each rewritten literal has a call target.
      final standIn = Procedure(
        Name(intDecodeRuntimeHelperName, userLib),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
        isStatic: true,
      );
      userLib.addProcedure(standIn);
      helpers = RuntimeHelpers({intDecodeRuntimeHelperName: standIn});
      return component;
    }

    IntEncryptPass makePass(
      Component component, {
      IntEncryptPassConfig config = const IntEncryptPassConfig(),
    }) {
      final keepResolver = KeepResolver(
        component: component,
        projectScope: projectScope,
        globalExcludes: RefractorConfig(passes: [config]).excludePatterns,
      );
      return IntEncryptPass(
        config: config,
        helpers: helpers,
        scope: ObfuscationScope(
          project: projectScope,
          keep: keepResolver.resolve(
            const IntEncryptDefinition().keepSources,
            config.exclude,
          ),
        ),
      );
    }

    test('int literal in a body is replaced with a decoding call', () async {
      final proc = Procedure(
        Name('secret'),
        ProcedureKind.Method,
        FunctionNode(Block([ReturnStatement(IntLiteral(3735928559))])),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(proc);

      component = makeRuntimeComponent();
      makePass(component).run(component);

      final ret =
          (proc.function.body! as Block).statements.first as ReturnStatement;
      final call = ret.expression! as StaticInvocation;
      expect(call.target.name.text, intDecodeRuntimeHelperName);
      // The call must decode back to the original value.
      expect(_decodedValue(call), 3735928559);
      // The original literal must not appear verbatim.
      expect(
        (call.arguments.positional[0] as IntLiteral).value,
        isNot(3735928559),
      );
    });

    test('literals below minMagnitude are left alone', () async {
      final proc = Procedure(
        Name('trivial'),
        ProcedureKind.Method,
        FunctionNode(
          Block([
            ExpressionStatement(IntLiteral(1)),
            ReturnStatement(IntLiteral(42)),
          ]),
        ),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(proc);

      component = makeRuntimeComponent();
      final result = makePass(component).run(component);

      final body = proc.function.body! as Block;
      // 1 stays inline (abs < 2); 42 is encoded.
      expect(
        (body.statements[0] as ExpressionStatement).expression,
        isA<IntLiteral>(),
      );
      expect(
        (body.statements[1] as ReturnStatement).expression,
        isA<StaticInvocation>(),
      );
      expect(result.report.metadata['ints_encrypted'], '1');
    });

    test('int literal inside a ConstantExpression is NOT replaced', () async {
      final constExpr = ConstantExpression(IntConstant(99999));
      final proc = Procedure(
        Name('constTest'),
        ProcedureKind.Method,
        FunctionNode(Block([ReturnStatement(constExpr)])),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(proc);

      component = makeRuntimeComponent();
      makePass(component).run(component);

      final ret =
          (proc.function.body! as Block).statements.first as ReturnStatement;
      expect(ret.expression, isA<ConstantExpression>());
    });

    test('int literal in an annotation is NOT replaced', () async {
      final cls = Class(name: 'Annotated', fileUri: userLib.fileUri)
        ..addAnnotation(IntLiteral(123456));
      userLib.addClass(cls);

      component = makeRuntimeComponent();
      makePass(component).run(component);

      expect(cls.annotations.first, isA<IntLiteral>());
      expect((cls.annotations.first as IntLiteral).value, 123456);
    });

    test('@Refractor.keep() class is exempt', () async {
      final annotationLib = makeRefractorAnnotationLibrary();
      final kept = IntLiteral(777777);
      final cls = Class(name: 'Keeper', fileUri: userLib.fileUri)
        ..addAnnotation(makeRefractorKeepAnnotation(annotationLib))
        ..addProcedure(
          Procedure(
            Name('run'),
            ProcedureKind.Method,
            FunctionNode(Block([ReturnStatement(kept)])),
            fileUri: userLib.fileUri,
          ),
        );
      userLib.addClass(cls);

      final comp = makeComponent(
        coreLib: coreLib,
        userLib: userLib,
        extraLibraries: [annotationLib],
      );
      final standIn = Procedure(
        Name(intDecodeRuntimeHelperName, userLib),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
        isStatic: true,
      );
      userLib.addProcedure(standIn);
      helpers = RuntimeHelpers({intDecodeRuntimeHelperName: standIn});
      makePass(comp).run(comp);

      final ret =
          (cls.procedures.first.function.body! as Block).statements.first
              as ReturnStatement;
      expect(ret.expression, isA<IntLiteral>());
      expect((ret.expression! as IntLiteral).value, 777777);
    });

    test('uses per-literal keys instead of one fixed key', () async {
      final proc = Procedure(
        Name('keys'),
        ProcedureKind.Method,
        FunctionNode(
          Block([
            ExpressionStatement(IntLiteral(1000)),
            ReturnStatement(IntLiteral(2000)),
          ]),
        ),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(proc);

      component = makeRuntimeComponent();
      makePass(component).run(component);

      final body = proc.function.body! as Block;
      final first =
          (body.statements[0] as ExpressionStatement).expression
              as StaticInvocation;
      final second =
          (body.statements[1] as ReturnStatement).expression!
              as StaticInvocation;
      final firstKey = (first.arguments.positional[1] as IntLiteral).value;
      final secondKey = (second.arguments.positional[1] as IntLiteral).value;
      expect(firstKey, isNot(secondKey));
      expect(_decodedValue(first), 1000);
      expect(_decodedValue(second), 2000);
    });

    test('reports the encrypted int count', () async {
      final proc = Procedure(
        Name('counted'),
        ProcedureKind.Method,
        FunctionNode(Block([ReturnStatement(IntLiteral(12345))])),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(proc);

      component = makeRuntimeComponent();
      final result = makePass(component).run(component);

      expect(result, isA<PassSucceeded>());
      expect(result.report.passName, 'int_encrypt');
      expect(result.report.metadata['ints_encrypted'], '1');
    });

    test('dart: library ints are not encrypted', () async {
      coreLib.addProcedure(
        Procedure(
          Name('coreHelper'),
          ProcedureKind.Method,
          FunctionNode(Block([ReturnStatement(IntLiteral(55555))])),
          fileUri: coreLib.fileUri,
        ),
      );
      final userProc = Procedure(
        Name('userFn'),
        ProcedureKind.Method,
        FunctionNode(Block([ReturnStatement(IntLiteral(66666))])),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(userProc);

      component = makeRuntimeComponent();
      makePass(component).run(component);

      final coreHelper = coreLib.procedures.firstWhere(
        (procedure) => procedure.name.text == 'coreHelper',
      );
      final coreRet =
          (coreHelper.function.body! as Block).statements.first
              as ReturnStatement;
      expect(coreRet.expression, isA<IntLiteral>());
    });

    test('a helper renamed by an earlier pass is still used', () async {
      final proc = Procedure(
        Name('renamedHelper'),
        ProcedureKind.Method,
        FunctionNode(Block([ReturnStatement(IntLiteral(4242))])),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(proc);
      component = makeRuntimeComponent();
      // What a rename pass listed first does to the injected helper.
      final helper = helpers.require(intDecodeRuntimeHelperName)
        ..name = Name('a', userLib);

      makePass(component).run(component);

      final ret =
          (proc.function.body! as Block).statements.first as ReturnStatement;
      final call = ret.expression! as StaticInvocation;
      expect(call.target, same(helper));
      expect(_decodedValue(call), 4242);
    });

    test('a missing decode helper fails the pass', () async {
      final proc = Procedure(
        Name('noHelper'),
        ProcedureKind.Method,
        FunctionNode(Block([ReturnStatement(IntLiteral(8888))])),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(proc);

      // No makeRuntimeComponent(): the helper is absent.
      final comp = makeComponent(coreLib: coreLib, userLib: userLib);
      final result = makePass(comp).run(comp);

      final ret =
          (proc.function.body! as Block).statements.first as ReturnStatement;
      expect(ret.expression, isA<IntLiteral>());
      expect(result, isA<PassFailed>());
      expect(result.report.message, contains(intDecodeRuntimeHelperName));
    });
  });
}
