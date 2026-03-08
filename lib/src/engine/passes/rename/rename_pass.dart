import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/passes/rename/name_allocator.dart';
import 'package:refractor/src/engine/passes/rename/override_family/override_family_analyzer.dart';
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
    // Phase 0 + 0.5: analyze families and allocate names.
    final analysis = OverrideFamilyAnalyzer().analyze(component, context);
    final memberRenames = NameAllocator().allocate(
      analysis,
      context.nameGenerator,
    );

    // Record allocated names in the symbol table.
    for (final entry in memberRenames.entries) {
      final originalName = memberNameText(entry.key);
      if (originalName.isNotEmpty) {
        context.symbolTable.record(originalName, entry.value.text);
      }
    }

    // Phase 1: visit remaining declarations (classes, variables).
    final collector = RenameVisitor(
      context: context,
      preMemberRenames: memberRenames,
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
}
