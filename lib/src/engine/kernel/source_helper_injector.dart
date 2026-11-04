import 'dart:io';

import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/compiler/compiler.dart';
import 'package:refractor/src/engine/kernel/helper_source.dart';

export 'package:refractor/src/engine/kernel/helper_source.dart';

/// Injects runtime helpers written as plain Dart into a kernel [Component].
///
/// Instead of hand-building a helper's body as kernel IL, the helper is written
/// as ordinary Dart, compiled to kernel with the same [Compiler] used for the
/// program (so it matches the program's SDK), then linked in. Linking has three
/// steps, proven necessary by experiment:
///
///   1. **Merge** the compiled helper dill into the program component with
///      `loadComponentFromBinary`, which deduplicates shared SDK libraries by
///      canonical name (no second `dart:core`).
///   2. **Reparent** the wanted procedures into an existing program library,
///      unbinding each one's stale canonical name. A standalone helper library
///      is referenced only by the calls we add, not by an import, so AOT cannot
///      assign it a loading unit ("Unable to find loading unit"); moving the
///      procedures into a library already in the import graph fixes this.
///   3. **Drop** the now-empty helper library.
///
/// The helper is compiled from a random temp file, so its `file://` path would
/// otherwise reach the output binary through each procedure's `fileUri` and
/// the component's `uriToSource`, naming Refractor and the user's temp
/// directory and making every build differ. Reparented procedures are
/// therefore re-homed to [Library.fileUri] of the target library with their
/// source offsets cleared, and the helper's source entries are dropped.
class SourceHelperInjector {
  SourceHelperInjector({required Compiler compiler}) : _compiler = compiler;

  final Compiler _compiler;

  /// Compiles [helper], links it into [component], and reparents the named
  /// procedures into [targetLibrary]. Returns the reparented procedures keyed
  /// by name.
  Map<String, Procedure> inject(
    Component component,
    HelperSource helper, {
    required Library targetLibrary,
  }) {
    final tempDir = Directory.systemTemp.createTempSync('refractor_helper');
    try {
      final sourcePath = '${tempDir.path}/helper.dart';
      final dillPath = '${tempDir.path}/helper.dill';
      File(sourcePath).writeAsStringSync(helper.source);
      _compiler.compileToKernel(sourcePath, dillPath);

      final existingUris = component.libraries
          .map((library) => library.importUri)
          .toSet();
      loadComponentFromBinary(dillPath, component);
      final helperLibraries = component.libraries
          .where((library) => !existingUris.contains(library.importUri))
          .toList();

      final reparented = <String, Procedure>{};
      for (final library in helperLibraries) {
        for (final procedure in library.procedures.toList()) {
          if (!helper.procedureNames.contains(procedure.name.text)) continue;
          library.procedures.remove(procedure);
          procedure.parent = targetLibrary;
          targetLibrary.procedures.add(procedure);
          // Detach the stale canonical name bound under the helper library so
          // the binary writer rebinds it under [targetLibrary]. Unbinding the
          // whole component instead would also disturb the merged SDK
          // libraries' names and fail to rebind them.
          procedure.reference.canonicalName?.unbind();
          procedure.accept(_SourceLocationScrubber(targetLibrary.fileUri));
          reparented[procedure.name.text] = procedure;
        }
      }

      component.libraries.removeWhere(helperLibraries.contains);
      for (final library in helperLibraries) {
        component.uriToSource.remove(library.fileUri);
      }
      return reparented;
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  }
}

/// Points every node of a reparented helper at [fileUri] and clears its source
/// offsets, which index the discarded helper source rather than [fileUri].
class _SourceLocationScrubber extends RecursiveVisitor {
  _SourceLocationScrubber(this.fileUri);

  final Uri fileUri;

  @override
  void defaultTreeNode(TreeNode node) {
    node.fileOffset = TreeNode.noOffset;
    if (node is FileUriNode) node.fileUri = fileUri;
    switch (node) {
      case Procedure():
        node
          ..fileStartOffset = TreeNode.noOffset
          ..fileEndOffset = TreeNode.noOffset;
      case Member():
        node.fileEndOffset = TreeNode.noOffset;
      case FunctionNode():
        node.fileEndOffset = TreeNode.noOffset;
      case Block():
        node.fileEndOffset = TreeNode.noOffset;
      default:
    }
    super.defaultTreeNode(node);
  }
}
