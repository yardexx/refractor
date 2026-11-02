import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass/planning/pass_planner.dart';
import 'package:refractor/src/engine/passes/call_indirection/planning/call_indirection_plan.dart';
import 'package:refractor/src/engine/passes/call_indirection/selection/call_indirection_selection.dart';

/// Carries the selected call sites into the plan. There is no per-site data to
/// decide, so this stage is a straight hand-off.
final class CallIndirectionPlanner
    implements PassPlanner<CallIndirectionSelection, CallIndirectionPlan> {
  const CallIndirectionPlanner();

  @override
  CallIndirectionPlan plan(
    Component component,
    CallIndirectionSelection selection,
  ) {
    return CallIndirectionPlan(sites: selection.orderedSites);
  }
}
