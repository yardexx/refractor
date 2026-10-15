import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel_toolkit/traversal/scoped_visiting.dart';
import 'package:refractor/src/engine/pass/selection/pass_selector.dart';
import 'package:refractor/src/engine/passes/opaque_predicate/selection/opaque_predicate_selection.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

/// Collects the `if` conditions within the obfuscatable scope.
final class OpaquePredicateSelector
    implements PassSelector<OpaquePredicateSelection> {
  OpaquePredicateSelector({required ObfuscationScope scope}) : _scope = scope;

  final ObfuscationScope _scope;

  @override
  OpaquePredicateSelection select(Component component) {
    final collector = _OpaquePredicateSelectionCollector(scope: _scope);
    component.accept(collector);
    return OpaquePredicateSelection(
      orderedSites: collector.sites,
      liveVariables: collector.liveVariables,
    );
  }
}

final class _OpaquePredicateSelectionCollector extends RecursiveVisitor
    with ScopedVisiting {
  _OpaquePredicateSelectionCollector({required this.scope});

  @override
  final ObfuscationScope scope;

  final List<IfStatement> sites = <IfStatement>[];
  final Map<IfStatement, VariableDeclaration> liveVariables =
      <IfStatement, VariableDeclaration>{};

  // Int variables in scope at the current point, in declaration order; the
  // last is the nearest. Holds parameters and block-local declarations alike,
  // pushed as they are visited and popped when their function or block ends.
  final List<VariableDeclaration> _intScope = <VariableDeclaration>[];

  static bool _isInt(DartType type) =>
      type is InterfaceType && type.classNode.name == 'int';

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
    for (final field in node.fields) {
      field.accept(this);
    }
  }

  @override
  void visitProcedure(Procedure node) {
    visitAnnotations(node.annotations);
    if (!isScopedMember(node)) {
      return;
    }
    node.function.accept(this);
  }

  @override
  void visitField(Field node) {
    visitAnnotations(node.annotations);
    if (!isScopedMember(node)) {
      return;
    }
    node.initializer?.accept(this);
  }

  @override
  void visitConstructor(Constructor node) {
    visitAnnotations(node.annotations);
    if (!isScopedMember(node)) {
      return;
    }
    for (final initializer in node.initializers) {
      initializer.accept(this);
    }
    node.function.accept(this);
  }

  @override
  void visitFunctionNode(FunctionNode node) {
    // Parameters (visited by super) and anything declared in the body are
    // scoped to this function.
    final saved = _intScope.length;
    super.visitFunctionNode(node);
    _intScope.length = saved;
  }

  @override
  void visitBlock(Block node) {
    final saved = _intScope.length;
    super.visitBlock(node);
    _intScope.length = saved;
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    // Visit the initializer first (the variable is not yet in scope there),
    // then make it available to following statements.
    super.visitVariableDeclaration(node);
    if (_isInt(node.type)) {
      _intScope.add(node);
    }
  }

  @override
  void visitIfStatement(IfStatement node) {
    if (!inConstContext) {
      sites.add(node);
      if (_intScope.isNotEmpty) {
        liveVariables[node] = _intScope.last;
      }
    }
    super.visitIfStatement(node);
  }
}
