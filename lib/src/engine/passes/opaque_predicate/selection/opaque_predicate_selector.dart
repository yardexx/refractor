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
    return OpaquePredicateSelection(orderedSites: collector.sites);
  }
}

final class _OpaquePredicateSelectionCollector extends RecursiveVisitor
    with ScopedVisiting {
  _OpaquePredicateSelectionCollector({required this.scope});

  @override
  final ObfuscationScope scope;

  final List<IfStatement> sites = <IfStatement>[];

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
  void visitIfStatement(IfStatement node) {
    if (!inConstContext) {
      sites.add(node);
    }
    super.visitIfStatement(node);
  }
}
