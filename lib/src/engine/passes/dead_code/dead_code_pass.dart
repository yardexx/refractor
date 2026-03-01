import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/passes/dead_code/dead_code_transformer.dart';
import 'package:refractor/src/engine/runner/pass.dart';
import 'package:refractor/src/engine/runner/pass_context.dart';

/// Obfuscation pass that inserts unreachable dead-code branches into procedure
/// bodies to confuse static analysis and decompilers.
///
/// Inserts at most [maxInsertionsPerProcedure] dummy `if (false) { ... }`
/// blocks per procedure. The Dart VM optimizer eliminates these at runtime,
/// so there is no performance impact.
class DeadCodePass extends Pass {
  DeadCodePass({this.maxInsertionsPerProcedure = 1});
  final int maxInsertionsPerProcedure;

  @override
  String get name => 'dead_code';

  @override
  void run(Component component, PassContext context) {
    final intClass = _resolveIntClass(component);

    final transformer = DeadCodeTransformer(
      context: context,
      maxInsertions: maxInsertionsPerProcedure,
      intClass: intClass,
    );

    component.transformChildren(transformer);
  }

  Class _resolveIntClass(Component component) {
    final coreLib = component.libraries.firstWhere(
      (l) => l.importUri.toString() == 'dart:core',
    );
    return coreLib.classes.firstWhere((c) => c.name == 'int');
  }
}
