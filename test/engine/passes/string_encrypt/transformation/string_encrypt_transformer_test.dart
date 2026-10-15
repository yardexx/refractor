import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/string_encrypt/planning/string_encrypt_planner.dart';
import 'package:refractor/src/engine/passes/string_encrypt/selection/string_encrypt_selector.dart';
import 'package:refractor/src/engine/passes/string_encrypt/transformation/string_encrypt_transformer.dart';
import 'package:test/test.dart';

import '../../../../helpers/kernel_helpers.dart';

void main() {
  group('StringEncryptTransformer', () {
    late Library coreLib;
    late Library convertLib;
    late Library userLib;
    late Component component;

    setUp(() {
      coreLib = makeDartCoreLibrary();
      convertLib = makeDartConvertLibrary();
      userLib = makeUserLibrary();
      component = makeComponent(
        coreLib: coreLib,
        userLib: userLib,
        extraLibraries: [convertLib],
      );
      // The engine injects the decode helper before the transformer runs; the
      // transformer resolves it by name. Supply a stand-in for these unit
      // tests so each rewritten literal has a procedure to call.
      userLib.addProcedure(
        Procedure(
          Name('refractorDecode', userLib),
          ProcedureKind.Method,
          FunctionNode(EmptyStatement()),
          fileUri: userLib.fileUri,
          isStatic: true,
        ),
      );
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
        scope: makeObfuscationScope(),
        excludedLiteralPatterns: const [],
      ).select(component);
      final plan = await StringEncryptPlanner(seed: 42).plan(
        component,
        selection,
      );

      final output = StringEncryptTransformer(
        scope: makeObfuscationScope(),
      ).apply(component, plan);
      final transformOutput = await output;

      expect(transformOutput.encryptedCount, 2);
      expect(transformOutput.records, hasLength(2));
      expect(transformOutput.records.first.plaintext, 'first');
      expect(transformOutput.records.first.enclosingMemberName, 'counted');
      expect(transformOutput.records.first.enclosingMemberKind, 'procedure');

      final body =
          userLib.procedures
                  .firstWhere((procedure) => procedure.name.text == 'counted')
                  .function
                  .body!
              as Block;
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

    test('rewrites literal segments inside StringConcatenation only', () async {
      final leadingLiteral = StringLiteral('Hello ');
      final trailingLiteral = StringLiteral('!');
      final valueParam = VariableDeclaration('value');
      userLib.addProcedure(
        Procedure(
          Name('concat'),
          ProcedureKind.Method,
          FunctionNode(
            ReturnStatement(
              StringConcatenation([
                leadingLiteral,
                VariableGet(valueParam),
                trailingLiteral,
              ]),
            ),
            positionalParameters: [valueParam],
            requiredParameterCount: 1,
          ),
          fileUri: userLib.fileUri,
        ),
      );

      final selection = StringEncryptSelector(
        scope: makeObfuscationScope(),
        excludedLiteralPatterns: const [],
      ).select(component);
      final plan = await StringEncryptPlanner(seed: 42).plan(
        component,
        selection,
      );

      final transformOutput = await StringEncryptTransformer(
        scope: makeObfuscationScope(),
      ).apply(component, plan);

      expect(transformOutput.encryptedCount, 2);
      final returnStatement =
          userLib.procedures
                  .firstWhere((procedure) => procedure.name.text == 'concat')
                  .function
                  .body!
              as ReturnStatement;
      final concat = returnStatement.expression! as StringConcatenation;

      expect(concat.expressions[0], isA<StaticInvocation>());
      expect(concat.expressions[1], isA<VariableGet>());
      expect(concat.expressions[2], isA<StaticInvocation>());
    });
  });
}
