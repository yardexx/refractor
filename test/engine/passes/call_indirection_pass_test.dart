import 'package:kernel/kernel.dart';
import 'package:refractor/src/config/model/refractor_config.dart';
import 'package:refractor/src/engine/kernel/runtime_helpers.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/passes/call_indirection/call_indirection_pass.dart';
import 'package:refractor/src/engine/passes/call_indirection/config/call_indirection_config.dart';
import 'package:refractor/src/engine/passes/call_indirection/config/call_indirection_definition.dart';
import 'package:refractor/src/engine/passes/call_indirection/runtime/call_indirection_runtime.dart';
import 'package:refractor/src/policy/keep_resolver.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';
import 'package:refractor/src/project/project_scope.dart';
import 'package:test/test.dart';

import '../../helpers/kernel_helpers.dart';

void main() {
  group('CallIndirectionPass.run', () {
    late Library coreLib;
    late Library userLib;
    late Component component;
    late ProjectScope projectScope;
    late InterfaceType intType;

    late RuntimeHelpers helpers;

    setUp(() {
      helpers = RuntimeHelpers.none;
      coreLib = makeDartCoreLibrary();
      userLib = makeUserLibrary();
      projectScope = makeProjectScope();
      final intClass = coreLib.classes.firstWhere((c) => c.name == 'int');
      intType = InterfaceType(intClass, Nullability.nonNullable);
    });

    void addForwarderStandIn() {
      final standIn = Procedure(
        Name(callIndirectionHelperName, userLib),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
        isStatic: true,
      );
      userLib.addProcedure(standIn);
      helpers = RuntimeHelpers({callIndirectionHelperName: standIn});
    }

    CallIndirectionPass makePass(Component component) {
      const config = CallIndirectionPassConfig();
      final keepResolver = KeepResolver(
        component: component,
        projectScope: projectScope,
        globalExcludes: RefractorConfig(passes: [config]).excludePatterns,
      );
      return CallIndirectionPass(
        config: config,
        helpers: helpers,
        scope: ObfuscationScope(
          project: projectScope,
          keep: keepResolver.resolve(
            const CallIndirectionDefinition().keepSources,
            config.exclude,
          ),
        ),
      );
    }

    /// A static `int` target in the user library and a caller whose body is the
    /// single statement [callerBody]; returns the caller for inspection.
    Procedure addTargetAndCaller({
      required DartType returnType,
      required Statement Function(Procedure target) callerBody,
    }) {
      final target = Procedure(
        Name('target'),
        ProcedureKind.Method,
        FunctionNode(ReturnStatement(), returnType: returnType),
        fileUri: userLib.fileUri,
        isStatic: true,
      );
      userLib.addProcedure(target);
      final caller = Procedure(
        Name('caller'),
        ProcedureKind.Method,
        FunctionNode(Block([callerBody(target)])),
        fileUri: userLib.fileUri,
        isStatic: true,
      );
      userLib.addProcedure(caller);
      return caller;
    }

    test('an eligible static call is routed through the forwarder', () async {
      final caller = addTargetAndCaller(
        returnType: intType,
        callerBody: (target) => ReturnStatement(
          StaticInvocation(target, Arguments([IntLiteral(1), IntLiteral(2)])),
        ),
      );
      addForwarderStandIn();
      component = makeComponent(coreLib: coreLib, userLib: userLib);

      final result = await makePass(component).run(component);

      final ret =
          (caller.function.body! as Block).statements.first as ReturnStatement;
      // int return -> wrapped in `as int`.
      final as = ret.expression! as AsExpression;
      expect(as.type, intType);
      final invoke = as.operand as StaticInvocation;
      expect(invoke.target.name.text, callIndirectionHelperName);
      // A constant tear-off, as the CFE emits: the VM rejects a bare
      // StaticTearOff expression.
      final tearOff = invoke.arguments.positional[0] as ConstantExpression;
      expect(
        (tearOff.constant as StaticTearOffConstant).target.name.text,
        'target',
      );
      expect(invoke.arguments.positional[1], isA<ListLiteral>());
      expect(
        (invoke.arguments.positional[1] as ListLiteral).expressions,
        hasLength(2),
      );
      expect(result.report.metadata['calls_indirected'], '1');
    });

    test('a void call is routed without an added cast', () async {
      final caller = addTargetAndCaller(
        returnType: const VoidType(),
        callerBody: (target) =>
            ExpressionStatement(StaticInvocation(target, Arguments([]))),
      );
      addForwarderStandIn();
      component = makeComponent(coreLib: coreLib, userLib: userLib);

      await makePass(component).run(component);

      final stmt =
          (caller.function.body! as Block).statements.first
              as ExpressionStatement;
      final invoke = stmt.expression as StaticInvocation;
      expect(invoke.target.name.text, callIndirectionHelperName);
    });

    test('a call to an out-of-scope (dart:) target is left direct', () async {
      final coreTarget = Procedure(
        Name('sdkFn'),
        ProcedureKind.Method,
        FunctionNode(ReturnStatement(), returnType: intType),
        fileUri: coreLib.fileUri,
        isStatic: true,
      );
      coreLib.addProcedure(coreTarget);
      final caller = Procedure(
        Name('caller'),
        ProcedureKind.Method,
        FunctionNode(
          Block([ReturnStatement(StaticInvocation(coreTarget, Arguments([])))]),
        ),
        fileUri: userLib.fileUri,
        isStatic: true,
      );
      userLib.addProcedure(caller);
      addForwarderStandIn();
      component = makeComponent(coreLib: coreLib, userLib: userLib);

      final result = await makePass(component).run(component);

      final ret =
          (caller.function.body! as Block).statements.first as ReturnStatement;
      final invoke = ret.expression! as StaticInvocation;
      expect(invoke.target.name.text, 'sdkFn');
      expect(result.report.isEmpty, isTrue);
    });

    test('a missing forwarder helper fails the pass', () async {
      final caller = addTargetAndCaller(
        returnType: intType,
        callerBody: (target) => ReturnStatement(
          StaticInvocation(target, Arguments([IntLiteral(1)])),
        ),
      );
      // No forwarder stand-in added.
      component = makeComponent(coreLib: coreLib, userLib: userLib);

      final result = await makePass(component).run(component);

      final ret =
          (caller.function.body! as Block).statements.first as ReturnStatement;
      expect(ret.expression, isA<StaticInvocation>());
      expect((ret.expression! as StaticInvocation).target.name.text, 'target');
      expect(result, isA<PassFailed>());
      expect(result.report.message, contains(callIndirectionHelperName));
    });
  });
}
