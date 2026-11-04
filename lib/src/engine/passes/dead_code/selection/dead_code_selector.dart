import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel_toolkit/traversal/scoped_visiting.dart';
import 'package:refractor/src/engine/pass/selection/pass_selector.dart';
import 'package:refractor/src/engine/passes/dead_code/selection/dead_code_selection.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

/// Collects functions that can carry a guarded dead-code block within the
/// obfuscatable scope.
final class DeadCodeSelector implements PassSelector<DeadCodeSelection> {
  DeadCodeSelector({required ObfuscationScope scope}) : _scope = scope;

  final ObfuscationScope _scope;

  @override
  DeadCodeSelection select(Component component) {
    final collector = _DeadCodeSelectionCollector(scope: _scope);
    component.accept(collector);
    return DeadCodeSelection(
      orderedFunctions: collector.functions,
      sites: collector.sites,
    );
  }
}

final class _DeadCodeSelectionCollector extends RecursiveVisitor
    with ScopedVisiting {
  _DeadCodeSelectionCollector({required this.scope});

  @override
  final ObfuscationScope scope;

  final List<FunctionNode> functions = <FunctionNode>[];
  final Map<FunctionNode, List<DeadCodeSite>> sites =
      <FunctionNode, List<DeadCodeSite>>{};

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
    final functionSites = deadCodeSites(function);
    if (functionSites.isNotEmpty) {
      functions.add(function);
      sites[function] = functionSites;
    }
  }
}
