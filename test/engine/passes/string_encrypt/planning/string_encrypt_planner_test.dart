import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/string_encrypt/planning/string_encrypt_plan.dart';
import 'package:refractor/src/engine/passes/string_encrypt/planning/string_encrypt_planner.dart';
import 'package:refractor/src/engine/passes/string_encrypt/selection/string_encrypt_selection.dart';
import 'package:refractor/src/engine/passes/string_encrypt/selection/string_encrypt_selector.dart';
import 'package:refractor/src/engine/passes/string_encrypt/string_encrypt_codec.dart';
import 'package:refractor/src/policy/string_encrypt_policy_view.dart';
import 'package:test/test.dart';

import '../../../../helpers/kernel_helpers.dart';

void main() {
  group('StringEncryptPlanner', () {
    late Library coreLib;
    late Library userLib;
    late Component component;

    setUp(() {
      coreLib = makeDartCoreLibrary();
      userLib = makeUserLibrary();
      component = makeComponent(coreLib: coreLib, userLib: userLib);
    });

    Future<_PlannedFixture> planFixture() async {
      final firstLiteral = StringLiteral('first');
      final secondLiteral = StringLiteral('second');
      userLib.addProcedure(
        Procedure(
          Name('planned'),
          ProcedureKind.Method,
          FunctionNode(
            Block([
              ExpressionStatement(firstLiteral),
              ExpressionStatement(secondLiteral),
            ]),
          ),
          fileUri: userLib.fileUri,
        ),
      );

      final selection = StringEncryptSelector(
        projectScope: makeProjectScope(),
        policy: const StringEncryptPolicyView(),
      ).select(component);
      final plan = await StringEncryptPlanner(seed: 42).plan(
        component,
        selection,
      );

      return _PlannedFixture(
        selection: selection,
        plan: plan,
        literals: [firstLiteral, secondLiteral],
      );
    }

    test('creates one rewrite per selected literal', () async {
      final fixture = await planFixture();

      expect(
        fixture.plan.rewrites.length,
        fixture.selection.selectedLiteralCount,
      );
      expect(fixture.plan.plannedLiteralCount, 2);
    });

    test('preserves explicit selection order in the plan', () async {
      final fixture = await planFixture();

      expect(
        fixture.selection.orderedLiterals,
        [same(fixture.literals[0]), same(fixture.literals[1])],
      );
      expect(
        fixture.plan.rewrites.keys.toList(),
        [same(fixture.literals[0]), same(fixture.literals[1])],
      );
    });

    test('generates non-zero keys in selection order', () async {
      final fixture = await planFixture();

      final firstRewrite = fixture.plan.rewriteFor(fixture.literals[0]);
      final secondRewrite = fixture.plan.rewriteFor(fixture.literals[1]);

      expect(firstRewrite, isNotNull);
      expect(secondRewrite, isNotNull);
      expect(firstRewrite!.key, isNonZero);
      expect(secondRewrite!.key, isNonZero);
      expect(firstRewrite.key, isNot(equals(secondRewrite.key)));
    });

    test('stores encoded bytes computed by StringEncryptCodec', () async {
      final fixture = await planFixture();

      for (final literal in fixture.literals) {
        final rewrite = fixture.plan.rewriteFor(literal)!;
        expect(
          rewrite.encodedBytes,
          StringEncryptCodec.encodeWithKey(literal.value, rewrite.key),
        );
      }
    });

    test(
      'encoded bytes differ from the old single-step xor baseline',
      () async {
        final fixture = await planFixture();
        final rewrite = fixture.plan.rewriteFor(fixture.literals.first)!;

        expect(
          rewrite.encodedBytes,
          isNot(
            equals(
              _oldSingleStepEncode(
                fixture.literals.first.value,
                rewrite.key,
              ),
            ),
          ),
        );
      },
    );
  });
}

final class _PlannedFixture {
  const _PlannedFixture({
    required this.selection,
    required this.plan,
    required this.literals,
  });

  final StringEncryptSelection selection;
  final StringEncryptPlan plan;
  final List<StringLiteral> literals;
}

List<int> _oldSingleStepEncode(String value, int key) {
  return value.codeUnits.map((byte) => byte ^ key).toList(growable: false);
}
