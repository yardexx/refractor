import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/virtualize/selection/virtualize_selection.dart';
import 'package:refractor/src/project/project_scope.dart';
import 'package:refractor/src/utils/rename_helpers.dart';

/// Collects in-scope procedures annotated `@Refractor.virtualize()` and not
/// `@Refractor.keep()`.
final class VirtualizeSelector {
  VirtualizeSelector({required ProjectScope projectScope})
    : _projectScope = projectScope;

  final ProjectScope _projectScope;

  VirtualizeSelection select(Component component) {
    final collector = _Collector(_projectScope);
    component.accept(collector);
    return VirtualizeSelection(collector.targets);
  }
}

final class _Collector extends RecursiveVisitor {
  _Collector(this._projectScope);

  final ProjectScope _projectScope;
  final List<Procedure> targets = <Procedure>[];

  @override
  void visitLibrary(Library node) {
    if (!_projectScope.containsLibrary(node)) return;
    super.visitLibrary(node);
  }

  @override
  void visitProcedure(Procedure node) {
    if (hasRefractorVirtualizeAnnotation(node.annotations) &&
        !hasRefractorKeepAnnotation(node.annotations)) {
      targets.add(node);
    }
    super.visitProcedure(node);
  }
}
