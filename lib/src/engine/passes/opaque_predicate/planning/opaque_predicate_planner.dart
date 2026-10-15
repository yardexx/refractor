import 'dart:math';

import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass/planning/pass_planner.dart';
import 'package:refractor/src/engine/passes/opaque_predicate/planning/opaque_predicate_plan.dart';
import 'package:refractor/src/engine/passes/opaque_predicate/planning/planned_opaque_predicate.dart';
import 'package:refractor/src/engine/passes/opaque_predicate/selection/opaque_predicate_selection.dart';

/// Picks, per site, which opaque-true template to use and the constant to build
/// it from. Seeded, so a given seed yields the same plan every run.
///
/// Constants are drawn from `[1, _maxConstant]`, the range every template in
/// the rule table is proven true over.
final class OpaquePredicatePlanner
    implements PassPlanner<OpaquePredicateSelection, OpaquePredicatePlan> {
  OpaquePredicatePlanner({
    required int seed,
    required int templateCount,
  }) : _random = Random(seed),
       _templateCount = templateCount;

  static const int _maxConstant = 1000;

  final Random _random;
  final int _templateCount;

  @override
  Future<OpaquePredicatePlan> plan(
    Component component,
    OpaquePredicateSelection selection,
  ) async {
    final decisions = <PlannedOpaquePredicate>[
      for (final site in selection.orderedSites)
        PlannedOpaquePredicate(
          site: site,
          templateIndex: _random.nextInt(_templateCount),
          constant: _random.nextInt(_maxConstant) + 1,
        ),
    ];
    return OpaquePredicatePlan(decisions: decisions);
  }
}
