import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/opaque_predicate/planning/opaque_predicate_planner.dart';
import 'package:refractor/src/engine/passes/opaque_predicate/selection/opaque_predicate_selection.dart';
import 'package:test/test.dart';

void main() {
  group('OpaquePredicatePlanner', () {
    OpaquePredicateSelection selectionOf(int count) {
      return OpaquePredicateSelection(
        orderedSites: [
          for (var i = 0; i < count; i++)
            IfStatement(BoolLiteral(true), EmptyStatement(), null),
        ],
      );
    }

    Future<List<int>> choices(int seed, OpaquePredicateSelection selection) {
      return OpaquePredicatePlanner(seed: seed, templateCount: 3)
          .plan(Component(), selection)
          .then(
            (plan) => [
              for (final decision in plan.decisions) ...[
                decision.templateIndex,
                decision.constant,
              ],
            ],
          );
    }

    test('plans one decision per site', () async {
      final plan = await OpaquePredicatePlanner(
        seed: 1,
        templateCount: 3,
      ).plan(Component(), selectionOf(4));
      expect(plan.decisionCount, 4);
    });

    test('is deterministic for a seed and varies across seeds', () async {
      final selection = selectionOf(8);
      expect(await choices(42, selection), await choices(42, selection));
      expect(
        await choices(42, selection),
        isNot(await choices(43, selection)),
      );
    });

    test('keeps template index and constant in range', () async {
      final plan = await OpaquePredicatePlanner(
        seed: 7,
        templateCount: 3,
      ).plan(Component(), selectionOf(50));
      for (final decision in plan.decisions) {
        expect(decision.templateIndex, inInclusiveRange(0, 2));
        expect(decision.constant, inInclusiveRange(1, 1000));
      }
    });
  });
}
