import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/passes/rename/model/generated_names.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_mapping.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_scope.dart';
import 'package:refractor/src/utils/rename_helpers.dart';

/// Assigns obfuscated names to all declarations in a [RenameScope].
///
/// One concrete class. Takes a [RenameScope] + [GeneratedNames],
/// returns a [RenameMapping] with symbolMap.
///
/// Handles privacy wiring, family expansion, and symbolMap building.
class NameAllocator {
  /// Allocates from pre-generated names.
  ///
  /// Expands family names → one Name per member, adds `_` prefix for
  /// private members + sets library scope, builds symbolMap.
  RenameMapping allocate(RenameScope scope, GeneratedNames names) {
    final members = <Member, Name>{};
    final symbolMap = <String, String>{};

    // Expand families: one generated name → all members in the family.
    for (final family in scope.overrideFamilies.families) {
      final rawName = names.familyNames[family]!;
      final name = family.isPrivate
          ? Name('_$rawName', family.libraryScope)
          : Name(rawName);
      for (final member in family.members) {
        members[member] = name;
        final original = memberNameText(member);
        if (original.isNotEmpty) {
          symbolMap[original] = name.text;
        }
      }
    }

    // Singletons (top-level + static + constructors).
    for (final entry in names.singletonNames.entries) {
      final member = entry.key;
      final rawName = entry.value;
      final originalName = memberNameText(member);
      final isPrivate = originalName.startsWith('_');
      final lib = isPrivate ? member.enclosingLibrary : null;
      final name = Name(isPrivate ? '_$rawName' : rawName, lib);
      members[member] = name;
      if (originalName.isNotEmpty) {
        symbolMap[originalName] = name.text;
      }
    }

    // Classes.
    final classes = <Class, String>{};
    for (final entry in names.classNames.entries) {
      classes[entry.key] = entry.value;
      symbolMap[entry.key.name] = entry.value;
    }

    // Variables.
    final variables = <VariableDeclaration, String>{};
    for (final entry in names.variableNames.entries) {
      variables[entry.key] = entry.value;
      final originalName = entry.key.name;
      if (originalName != null && originalName.isNotEmpty) {
        symbolMap[originalName] = entry.value;
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
