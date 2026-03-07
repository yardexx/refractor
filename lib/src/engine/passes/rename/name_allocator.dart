import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/name_generator.dart';
import 'package:refractor/src/engine/passes/rename/override_family_analyzer.dart';

/// Assigns obfuscated [Name]s to override families, reusing names across
/// families whose class sets have no subtype overlap (ProGuard-style
/// name overloading).
class NameAllocator {
  /// Assigns one obfuscated [Name] per override family.
  ///
  /// [analysis] provides family-to-class mappings and subtype info.
  /// [generator] supplies fresh names when reuse is impossible.
  /// [libraryForFamily] returns the enclosing library for a
  /// given family ID (used for private name scoping).
  Map<int, Name> allocate(
    OverrideFamilyAnalysis analysis,
    NameGenerator generator, {
    required Library? Function(int familyId) libraryForFamily,
    required bool Function(int familyId) isPrivateFamily,
  }) {
    final result = <int, Name>{};

    // Separate public and private families.
    // Private names are scoped per-library, so they need
    // separate slot tracking.
    final publicFamilies = <int>[];
    final privateFamiliesByLib = <Library, List<int>>{};

    for (final familyId in _stableSortedFamilyIds(analysis)) {
      if (isPrivateFamily(familyId)) {
        final lib = libraryForFamily(familyId);
        if (lib != null) {
          privateFamiliesByLib.putIfAbsent(lib, () => []).add(familyId);
        }
      } else {
        publicFamilies.add(familyId);
      }
    }

    // Allocate public names with overloading.
    _allocateFamilies(publicFamilies, analysis, generator, result, null);

    // Allocate private names per library (private names are library-scoped).
    for (final entry in privateFamiliesByLib.entries) {
      _allocateFamilies(
        entry.value,
        analysis,
        generator,
        result,
        entry.key,
      );
    }

    return result;
  }

  void _allocateFamilies(
    List<int> familyIds,
    OverrideFamilyAnalysis analysis,
    NameGenerator generator,
    Map<int, Name> result,
    Library? privateLib,
  ) {
    // slots: obfuscated name → set of classes whose subtypes are "occupied"
    final slots = <String, Set<Class>>{};

    for (final familyId in familyIds) {
      final candidateClasses = analysis.familyClasses[familyId] ?? {};
      final candidateSubtypes = <Class>{};
      for (final cls in candidateClasses) {
        candidateSubtypes.addAll(analysis.subtypesOf[cls] ?? {cls});
      }

      // Try to find an existing slot with no overlap.
      String? reuseName;
      for (final entry in slots.entries) {
        if (entry.value.intersection(candidateSubtypes).isEmpty) {
          reuseName = entry.key;
          break;
        }
      }

      final String obfName;
      if (reuseName != null) {
        obfName = reuseName;
        slots[obfName]!.addAll(candidateSubtypes);
      } else {
        obfName = generator.next();
        slots[obfName] = Set<Class>.from(candidateSubtypes);
      }

      final nameStr = privateLib != null ? '_$obfName' : obfName;
      result[familyId] = Name(nameStr, privateLib);
    }
  }

  /// Returns family IDs in a stable order for deterministic allocation.
  List<int> _stableSortedFamilyIds(OverrideFamilyAnalysis analysis) {
    final ids = analysis.familyClasses.keys.toList()..sort();
    return ids;
  }
}
