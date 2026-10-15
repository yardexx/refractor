import 'dart:io';

import 'package:kernel/ast.dart';
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
///   2. **Reparent** the wanted procedures into an existing program library.
///      A standalone helper library is referenced only by the calls we add, not
///      by an import, so AOT cannot assign it a loading unit and fails with
///      "Unable to find loading unit". Moving the procedures into a library that
///      is already in the import graph fixes this.
///   3. **Drop** the now-empty helper library and unbind canonical names so the
///      binary writer recomputes them for the new structure.
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

      final existingUris =
          component.libraries.map((library) => library.importUri).toSet();
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
          reparented[procedure.name.text] = procedure;
        }
      }

      component.libraries.removeWhere(helperLibraries.contains);
      return reparented;
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  }
}
