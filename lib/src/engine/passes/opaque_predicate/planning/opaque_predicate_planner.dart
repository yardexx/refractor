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
    required int liveTemplateCount,
  }) : _random = Random(seed),
       _templateCount = templateCount,
       _liveTemplateCount = liveTemplateCount;

  static const int _maxConstant = 1000;

  final Random _random;
  final int _templateCount;
  final int _liveTemplateCount;

  @override
  OpaquePredicatePlan plan(
    Component component,
    OpaquePredicateSelection selection,
  ) {
    final decisions = <PlannedOpaquePredicate>[
      for (final site in selection.orderedSites) _planFor(site, selection),
    ];
    return OpaquePredicatePlan(decisions: decisions);
  }

  PlannedOpaquePredicate _planFor(
    IfStatement site,
    OpaquePredicateSelection selection,
  ) {
    // Prefer a data-dependent live predicate where an in-scope variable exists.
    final variable = selection.liveVariableFor(site);
    if (variable != null && _liveTemplateCount > 0) {
      return PlannedOpaquePredicate(
        site: site,
        templateIndex: _random.nextInt(_liveTemplateCount),
        constant: 0,
        variable: variable,
      );
    }
    return PlannedOpaquePredicate(
      site: site,
      templateIndex: _random.nextInt(_templateCount),
      constant: _random.nextInt(_maxConstant) + 1,
    );
  }
}
