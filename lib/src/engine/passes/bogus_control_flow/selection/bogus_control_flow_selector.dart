import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel_toolkit/traversal/scoped_visiting.dart';
import 'package:refractor/src/engine/pass/selection/pass_selector.dart';
import 'package:refractor/src/engine/passes/bogus_control_flow/selection/bogus_control_flow_selection.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

/// Collects functions that can carry a bogus branch within the obfuscatable
/// scope.
final class BogusControlFlowSelector
    implements PassSelector<BogusControlFlowSelection> {
  BogusControlFlowSelector({
    required ObfuscationScope scope,
    required int maxStatements,
  }) : _scope = scope,
       _maxStatements = maxStatements;

  final ObfuscationScope _scope;
  final int _maxStatements;

  @override
  BogusControlFlowSelection select(Component component) {
    final collector = _BogusControlFlowSelectionCollector(
      scope: _scope,
      maxStatements: _maxStatements,
    );
    component.accept(collector);
    return BogusControlFlowSelection(
      orderedFunctions: collector.functions,
      guardCandidates: collector.guardCandidates,
    );
  }
}

final class _BogusControlFlowSelectionCollector extends RecursiveVisitor
    with ScopedVisiting {
  _BogusControlFlowSelectionCollector({
    required this.scope,
    required int maxStatements,
  }) : _maxStatements = maxStatements;

  @override
  final ObfuscationScope scope;

  final int _maxStatements;
  final List<FunctionNode> functions = <FunctionNode>[];
  final Map<FunctionNode, List<VariableDeclaration>> guardCandidates =
      <FunctionNode, List<VariableDeclaration>>{};

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
    if (isBogusControlFlowTarget(function, maxStatements: _maxStatements)) {
      functions.add(function);
      guardCandidates[function] = bogusGuardCandidates(function);
    }
  }
}
