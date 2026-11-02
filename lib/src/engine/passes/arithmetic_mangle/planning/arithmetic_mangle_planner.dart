import 'dart:math';

import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass/planning/pass_planner.dart';
import 'package:refractor/src/engine/passes/arithmetic_mangle/planning/arithmetic_mangle_plan.dart';
import 'package:refractor/src/engine/passes/arithmetic_mangle/planning/planned_arithmetic_mangle.dart';
import 'package:refractor/src/engine/passes/arithmetic_mangle/selection/arithmetic_mangle_selection.dart';

/// Assigns each site a random constant for the multiplication identity. Seeded,
/// so a given seed yields the same plan every run.
final class ArithmeticManglePlanner
    implements PassPlanner<ArithmeticMangleSelection, ArithmeticManglePlan> {
  ArithmeticManglePlanner({required int seed}) : _random = Random(seed);

  static const int _maxConstant = 0xFFFF;

  final Random _random;

  @override
  ArithmeticManglePlan plan(
    Component component,
    ArithmeticMangleSelection selection,
  ) {
    final decisions = <InstanceInvocation, PlannedArithmeticMangle>{
      for (final site in selection.orderedSites)
        site: PlannedArithmeticMangle(
          site: site,
          constant: _random.nextInt(_maxConstant) + 1,
        ),
    };
    return ArithmeticManglePlan(decisions: decisions);
  }
}
