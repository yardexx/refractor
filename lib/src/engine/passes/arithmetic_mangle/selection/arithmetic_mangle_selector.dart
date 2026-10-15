import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel_toolkit/traversal/scoped_visiting.dart';
import 'package:refractor/src/engine/pass/selection/pass_selector.dart';
import 'package:refractor/src/engine/passes/arithmetic_mangle/selection/arithmetic_mangle_selection.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

/// Tree matcher that collects integer `+` and `*` invocations within the
/// obfuscatable scope.
///
/// A site matches only when it is the SDK `int`/`num` operator (not a
/// user-defined `operator +`) and its result type is `int`, which together
/// guarantee both operands are integers — the precondition for the mangling
/// identities.
final class ArithmeticMangleSelector
    implements PassSelector<ArithmeticMangleSelection> {
  ArithmeticMangleSelector({required ObfuscationScope scope}) : _scope = scope;

  final ObfuscationScope _scope;

  @override
  ArithmeticMangleSelection select(Component component) {
    final collector = _ArithmeticMangleSelectionCollector(scope: _scope);
    component.accept(collector);
    return ArithmeticMangleSelection(orderedSites: collector.sites);
  }
}

/// Whether [node] is an integer `+` or `*` safe to mangle.
bool isMangleableIntArithmetic(InstanceInvocation node) {
  final name = node.name.text;
  if (name != '+' && name != '*') {
    return false;
  }
  final owner = node.interfaceTarget.enclosingClass?.name;
  if (owner != 'int' && owner != 'num') {
    return false;
  }
  final returnType = node.functionType.returnType;
  return returnType is InterfaceType && returnType.classNode.name == 'int';
}

final class _ArithmeticMangleSelectionCollector extends RecursiveVisitor
    with ScopedVisiting {
  _ArithmeticMangleSelectionCollector({required this.scope});

  @override
  final ObfuscationScope scope;

  final List<InstanceInvocation> sites = <InstanceInvocation>[];

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
  void visitInstanceInvocation(InstanceInvocation node) {
    if (!inConstContext && isMangleableIntArithmetic(node)) {
      sites.add(node);
    }
    super.visitInstanceInvocation(node);
  }
}
