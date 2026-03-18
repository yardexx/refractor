import 'package:refractor/src/engine/passes/rename/model/rename_plan.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_slot.dart';
import 'package:refractor/src/utils/rename_helpers.dart';

class RenameSlotBuilder {
  List<RenameSlot> build(RenamePlan plan) {
    return [
      for (final family in plan.memberFamilies) RenameSlot.family(family),
      for (final member in plan.singletonMembers)
        RenameSlot.singletonMember(member, memberNameText(member)),
      for (final cls in plan.classes) RenameSlot.classType(cls),
      for (final variable in plan.variables)
        if (variable.name != null && variable.name!.isNotEmpty)
          RenameSlot.variable(variable, variable.name!),
    ];
  }
}
