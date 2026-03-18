import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_mapping.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_plan.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_slot.dart';
import 'package:refractor/src/utils/rename_helpers.dart';

class NameMaterializer {
  RenameMapping materialize(Map<RenameSlot, String> assignedNames) {
    final members = <Member, Name>{};
    final classes = <Class, String>{};
    final variables = <VariableDeclaration, String>{};
    final symbolMap = <String, String>{};

    for (final entry in assignedNames.entries) {
      final slot = entry.key;
      final rawName = entry.value;

      switch (slot.kind) {
        case RenameSlotKind.family:
          final family = slot.target as MemberFamily;
          final name = family.privacyScope == null
              ? Name(rawName)
              : Name('_$rawName', family.privacyScope);
          for (final member in family.members) {
            members[member] = name;
          }
          if (slot.originalName.isNotEmpty) {
            symbolMap[symbolKeyForName(name)] = slot.originalName;
          }
        case RenameSlotKind.singletonMember:
          final member = slot.target as Member;
          final name = slot.privacyScope == null
              ? Name(rawName)
              : Name('_$rawName', slot.privacyScope);
          members[member] = name;
          if (slot.originalName.isNotEmpty) {
            symbolMap[symbolKeyForName(name)] = slot.originalName;
          }
        case RenameSlotKind.classType:
          final cls = slot.target as Class;
          classes[cls] = rawName;
          if (slot.originalName.isNotEmpty) {
            symbolMap[rawName] = slot.originalName;
          }
        case RenameSlotKind.variable:
          final variable = slot.target as VariableDeclaration;
          variables[variable] = rawName;
          if (slot.originalName.isNotEmpty) {
            symbolMap[rawName] = slot.originalName;
          }
      }
    }

    return RenameMapping(
      members: members,
      classes: classes,
      variables: variables,
      symbolMap: symbolMap,
    );
  }
}
