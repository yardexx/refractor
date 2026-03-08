import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/name_generator.dart';
import 'package:refractor/src/engine/passes/rename/override_family/override_family_analysis.dart';
import 'package:refractor/src/engine/passes/rename/rename_helpers.dart';

/// Assigns obfuscated [Name]s to override families.
///
/// Members in the same family get the same name. Each distinct family
/// gets a unique generated name.
class NameAllocator {
  Map<Member, Name> allocate(
    OverrideFamilyAnalysis analysis,
    NameGenerator generator,
  ) {
    final familyNames = <int, Name>{};

    for (final familyId in _stableSortedFamilyIds(analysis)) {
      final privateLib = _privateLibrary(familyId, analysis);
      final obfName = generator.next();
      final nameStr = privateLib != null ? '_$obfName' : obfName;
      familyNames[familyId] = Name(nameStr, privateLib);
    }

    final memberRenames = <Member, Name>{};
    for (final entry in analysis.familyOf.entries) {
      final name = familyNames[entry.value];
      if (name != null) {
        memberRenames[entry.key] = name;
      }
    }
    return memberRenames;
  }

  /// Returns the [Library] if this family is private, or `null` if public.
  Library? _privateLibrary(int familyId, OverrideFamilyAnalysis analysis) {
    for (final entry in analysis.familyOf.entries) {
      if (entry.value == familyId) {
        final name = memberNameText(entry.key);
        if (name.startsWith('_')) return entry.key.enclosingLibrary;
      }
    }
    return null;
  }

  List<int> _stableSortedFamilyIds(OverrideFamilyAnalysis analysis) {
    return (analysis.familyOf.values.toSet().toList())..sort();
  }
}
