import 'package:refractor/src/engine/pass/planning/pass_plan.dart';
import 'package:refractor/src/engine/passes/rename/reporting/rename_mapping.dart';

final class RenamePlan extends PassPlan {
  const RenamePlan({
    required this.mapping,
    required this.plannedClasses,
    required this.plannedMembers,
    required this.plannedVariables,
  });

  final RenameMapping mapping;
  final int plannedClasses;
  final int plannedMembers;
  final int plannedVariables;
}
