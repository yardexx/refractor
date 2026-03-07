import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/passes/rename/name_allocator.dart';
import 'package:refractor/src/engine/passes/rename/override_family_analyzer.dart';
import 'package:refractor/src/engine/passes/rename/rename_helpers.dart';
import 'package:refractor/src/engine/passes/rename/rename_transformer.dart';
import 'package:refractor/src/engine/passes/rename/rename_visitor.dart';
import 'package:refractor/src/engine/runner/pass.dart';
import 'package:refractor/src/engine/runner/pass_context.dart';

/// Obfuscation pass that renames user-defined identifiers (classes, methods,
/// fields, variables) to short alphabetic names with ProGuard-style name
/// overloading.
///
/// Uses a multi-phase approach:
///   Phase 0   — analyze override families (members connected by inheritance).
///   Phase 0.5 — allocate obfuscated names to families, reusing names across
///               unrelated families.
///   Phase 1   — visit remaining declarations (classes, variables).
///   Phase 2   — apply all renames so declarations and references are updated.
///   Phase 3   — unbind canonical names for renamed user libraries so they can
///               be recomputed correctly by BinaryPrinter.writeComponentFile.
class RenamePass extends Pass {
  @override
  String get name => 'rename';

  @override
  void run(Component component, PassContext context) {
    // Phase 0: override family analysis.
    final analysis = OverrideFamilyAnalyzer().analyze(component, context);
    final familyMeta = _buildFamilyMetadata(analysis);

    // Phase 0.5: allocate names to families.
    final familyNames = NameAllocator().allocate(
      analysis,
      context.nameGenerator,
      libraryForFamily: (familyId) => familyMeta.libraryForFamily[familyId],
      isPrivateFamily: (familyId) =>
          familyMeta.isPrivateFamily[familyId] ?? false,
    );

    // Build pre-computed memberRenames from family assignments.
    final preMemberRenames = <Member, Name>{};
    for (final entry in analysis.familyOf.entries) {
      final name = familyNames[entry.value];
      if (name != null) {
        preMemberRenames[entry.key] = name;
        // Record in symbol table.
        final originalName = memberNameText(entry.key);
        if (originalName.isNotEmpty) {
          context.symbolTable.record(originalName, name.text);
        }
      }
    }

    // Phase 1: visit remaining declarations (classes, variables).
    final collector = RenameVisitor(
      context: context,
      preMemberRenames: preMemberRenames,
    );
    component.accept(collector);

    // Phase 2: apply renames using a Transformer.
    final renamer = RenameTransformer(
      classRenames: collector.classRenames,
      memberRenames: collector.memberRenames,
      variableRenames: collector.variableRenames,
      context: context,
    );
    component.transformChildren(renamer);

    // Phase 3: unbind canonical names for renamed user libraries.
    for (final lib in component.libraries) {
      if (context.shouldObfuscateLibrary(lib)) {
        lib.reference.canonicalName?.unbindAll();
      }
    }
  }

  _FamilyMetadata _buildFamilyMetadata(OverrideFamilyAnalysis analysis) {
    final libraryForFamily = <int, Library>{};
    final isPrivateFamily = <int, bool>{};

    for (final entry in analysis.familyOf.entries) {
      final member = entry.key;
      final familyId = entry.value;
      libraryForFamily.putIfAbsent(familyId, () => member.enclosingLibrary);
      isPrivateFamily.putIfAbsent(
        familyId,
        () => memberNameText(member).startsWith('_'),
      );
    }

    return _FamilyMetadata(
      libraryForFamily: libraryForFamily,
      isPrivateFamily: isPrivateFamily,
    );
  }
}

class _FamilyMetadata {
  _FamilyMetadata({
    required this.libraryForFamily,
    required this.isPrivateFamily,
  });

  final Map<int, Library> libraryForFamily;
  final Map<int, bool> isPrivateFamily;
}
