import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel_toolkit/traversal/scoped_visiting.dart';
import 'package:refractor/src/engine/pass/selection/pass_selector.dart';
import 'package:refractor/src/engine/passes/call_indirection/selection/call_indirection_selection.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

/// Collects direct static calls within the obfuscatable scope whose target is
/// itself in scope (project code, not kept, not SDK).
final class CallIndirectionSelector
    implements PassSelector<CallIndirectionSelection> {
  CallIndirectionSelector({required ObfuscationScope scope}) : _scope = scope;

  final ObfuscationScope _scope;

  @override
  CallIndirectionSelection select(Component component) {
    final collector = _CallIndirectionSelectionCollector(scope: _scope);
    component.accept(collector);
    return CallIndirectionSelection(orderedSites: collector.sites);
  }
}

final class _CallIndirectionSelectionCollector extends RecursiveVisitor
    with ScopedVisiting {
  _CallIndirectionSelectionCollector({required this.scope});

  @override
  final ObfuscationScope scope;

  final List<StaticInvocation> sites = <StaticInvocation>[];
  final Set<StaticInvocation> _seen = Set.identity();

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
  void visitStaticInvocation(StaticInvocation node) {
    if (!inConstContext &&
        isIndirectableCall(node) &&
        isScopedMember(node.target) &&
        _seen.add(node)) {
      sites.add(node);
    }
    // Recurse so nested calls (in the arguments) are considered too.
    super.visitStaticInvocation(node);
  }
}
