import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/passes/rename/rename_transformer.dart';
import 'package:refractor/src/engine/passes/rename/rename_visitor.dart';
import 'package:refractor/src/engine/runner/pass.dart';
import 'package:refractor/src/engine/runner/pass_context.dart';

/// Obfuscation pass that renames user-defined identifiers (classes, methods,
/// fields, variables) to short meaningless names like `_$0`, `_$1`, etc.
///
/// Uses a two-phase approach:
///   Phase 1 — collect all renameable nodes and assign obfuscated names.
///   Phase 2 — apply the renames so all declarations and references are
///             updated.
///   Phase 3 — unbind canonical names for renamed user libraries so they can
///             be recomputed correctly by BinaryPrinter.writeComponentFile.
class RenamePass extends Pass {
  @override
  String get name => 'rename';

  @override
  void run(Component component, PassContext context) {
    // Phase 1: collect declarations and assign new names.
    final collector = RenameVisitor(context: context);
    component.accept(collector);

    // Phase 2: apply renames using a Transformer.
    // Pass the identity-based maps so lookups work even after names are
    // mutated.
    final renamer = RenameTransformer(
      classRenames: collector.classRenames,
      memberRenames: collector.memberRenames,
      context: context,
    );
    component.transformChildren(renamer);

    // Phase 3: unbind canonical names for renamed user libraries so they can
    // be recomputed correctly by BinaryPrinter.writeComponentFile.
    // Without this, the old canonical name entries (pre-rename) would conflict
    // with the new names.
    for (final lib in component.libraries) {
      if (context.shouldObfuscateLibrary(lib)) {
        lib.reference.canonicalName?.unbindAll();
      }
    }
  }
}
