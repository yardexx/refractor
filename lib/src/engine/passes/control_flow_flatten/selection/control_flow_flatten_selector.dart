import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel_toolkit/traversal/scoped_visiting.dart';
import 'package:refractor/src/engine/pass/selection/pass_selector.dart';
import 'package:refractor/src/engine/passes/control_flow_flatten/selection/control_flow_flatten_selection.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

/// Collects flattenable function bodies within the obfuscatable scope.
final class ControlFlowFlattenSelector
    implements PassSelector<ControlFlowFlattenSelection> {
  ControlFlowFlattenSelector({required ObfuscationScope scope})
    : _scope = scope;

  final ObfuscationScope _scope;

  @override
  ControlFlowFlattenSelection select(Component component) {
    final collector = _ControlFlowFlattenSelectionCollector(scope: _scope);
    component.accept(collector);
    return ControlFlowFlattenSelection(orderedFunctions: collector.functions);
  }
}

final class _ControlFlowFlattenSelectionCollector extends RecursiveVisitor
    with ScopedVisiting {
  _ControlFlowFlattenSelectionCollector({required this.scope});

  @override
  final ObfuscationScope scope;

  final List<FunctionNode> functions = <FunctionNode>[];

  @override
  void visitLibrary(Library node) {
    if (!isScopedLibrary(node)) {
      return;
    }
    super.visitLibrary(node);
  }

  @override
  void visitClass(Class node) {
    visitAnnotations(node.annotations);
    if (!isScopedClass(node)) {
      return;
    }
    for (final constructor in node.constructors) {
      constructor.accept(this);
    }
    for (final procedure in node.procedures) {
      procedure.accept(this);
    }
  }

  @override
  void visitProcedure(Procedure node) {
    visitAnnotations(node.annotations);
    if (!isScopedMember(node)) {
      return;
    }
    _consider(node.function);
  }

  @override
  void visitConstructor(Constructor node) {
    visitAnnotations(node.annotations);
    if (!isScopedMember(node)) {
      return;
    }
    _consider(node.function);
  }

  void _consider(FunctionNode function) {
    if (isFlattenableFunction(function)) {
      functions.add(function);
    }
  }
}
