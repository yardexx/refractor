import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/string_encrypt/planning/string_encrypt_planner.dart';
import 'package:refractor/src/engine/passes/string_encrypt/selection/string_encrypt_selector.dart';
import 'package:refractor/src/engine/passes/string_encrypt/transformation/string_encrypt_transformer.dart';
import 'package:refractor/src/policy/string_encrypt_policy_view.dart';
import 'package:test/test.dart';

import '../../../../helpers/kernel_helpers.dart';

void main() {
  group('StringEncryptTransformer', () {
    late Library coreLib;
    late Library userLib;
    late Component component;
    late Procedure decodeProcedure;

    setUp(() {
      coreLib = makeDartCoreLibrary();
      userLib = makeUserLibrary();
      decodeProcedure = Procedure(
        Name(r'_obfDecode$', userLib),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
        isStatic: true,
      );
      userLib.addProcedure(decodeProcedure);
      component = makeComponent(coreLib: coreLib, userLib: userLib);
    });

    test('returns explicit transform output with encrypted count', () async {
      final firstLiteral = StringLiteral('first');
      final secondLiteral = StringLiteral('second');
      userLib.addProcedure(
        Procedure(
          Name('counted'),
          ProcedureKind.Method,
          FunctionNode(
            Block([
              ExpressionStatement(firstLiteral),
              ReturnStatement(secondLiteral),
            ]),
          ),
          fileUri: userLib.fileUri,
        ),
      );

      final selection = StringEncryptSelector(
        projectScope: makeProjectScope(),
        policy: const StringEncryptPolicyView(),
        decodeProcedure: decodeProcedure,
        excludePatterns: const [],
      ).select(component);
      final plan = await StringEncryptPlanner(seed: 42).plan(
        component,
        selection,
      );

      final output = StringEncryptTransformer(
        decodeProcedure: decodeProcedure,
        projectScope: makeProjectScope(),
      ).apply(component, plan);
      final transformOutput = await output;

      expect(transformOutput.encryptedCount, 2);
      expect(transformOutput.records, hasLength(2));
      expect(transformOutput.records.first.plaintext, 'first');
      expect(transformOutput.records.first.enclosingMemberName, 'counted');
      expect(transformOutput.records.first.enclosingMemberKind, 'procedure');

      final body = userLib.procedures.last.function.body! as Block;
      final firstExpression = body.statements.first as ExpressionStatement;
      final secondReturn = body.statements.last as ReturnStatement;
      final firstCall = firstExpression.expression as StaticInvocation;
      final secondCall = secondReturn.expression! as StaticInvocation;
      final firstRewrite = plan.rewriteFor(firstLiteral)!;
      final secondRewrite = plan.rewriteFor(secondLiteral)!;

      expect(
        (firstCall.arguments.positional[1] as IntLiteral).value,
        firstRewrite.key,
      );
      expect(
        (secondCall.arguments.positional[1] as IntLiteral).value,
        secondRewrite.key,
      );
      expect(
        (firstCall.arguments.positional[0] as ListLiteral).expressions
            .cast<IntLiteral>()
            .map((literal) => literal.value)
            .toList(),
        firstRewrite.encodedBytes,
      );
    });
  });
}
