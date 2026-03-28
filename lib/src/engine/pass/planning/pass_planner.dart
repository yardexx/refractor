import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/pass/planning/pass_plan.dart';
import 'package:refractor/src/engine/pass/selection/pass_selection.dart';

abstract interface class PassPlanner<
  S extends PassSelection,
  P extends PassPlan
> {
  Future<P> plan(Component component, S selection);
}
