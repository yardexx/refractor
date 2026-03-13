import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/pass_transformer.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_mapping.dart';

/// Applies a [RenameMapping] to the kernel AST.
///
/// Pure AST mutation: renames declarations and updates call sites.
class RenameTransformer extends PassTransformer {
  RenameTransformer({required this.mapping, required super.target});

  final RenameMapping mapping;

  /// Original names of renamed variables, captured before mutation.
  /// Used to match [NamedExpression]s at call sites to renamed parameters.
  late final Map<VariableDeclaration, String> _originalVarNames;

  /// Applies the mapping to [component]: transforms the AST and
  /// unbinds canonical names for renamed user libraries.
  void apply(Component component) {
    // Capture original names before any mutations happen.
    _originalVarNames = {
      for (final entry in mapping.variables.entries)
        entry.key: entry.key.name ?? '',
    };

    component.transformChildren(this);
    for (final lib in component.libraries) {
      if (target.shouldObfuscateLibrary(lib)) {
        lib.reference.canonicalName?.unbindAll();
      }
    }
  }

  @override
  TreeNode visitClass(Class node) {
    final obf = mapping.classes[node];
    if (obf != null) node.name = obf;
    return super.visitClass(node);
  }

  @override
  TreeNode visitProcedure(Procedure node) {
    final newName = mapping.members[node];
    if (newName != null) node.name = newName;
    return super.visitProcedure(node);
  }

  @override
  TreeNode visitField(Field node) {
    final newName = mapping.members[node];
    if (newName != null) node.name = newName;
    return super.visitField(node);
  }

  @override
  TreeNode visitConstructor(Constructor node) {
    final newName = mapping.members[node];
    if (newName != null) node.name = newName;
    return super.visitConstructor(node);
  }

  @override
  TreeNode visitVariableDeclaration(VariableDeclaration node) {
    final newName = mapping.variables[node];
    if (newName != null) node.name = newName;
    return super.visitVariableDeclaration(node);
  }

  // ---- Named argument renames ----

  /// Updates named arguments to match renamed parameters on the [target].
  void _updateNamedArguments(Arguments args, FunctionNode target) {
    if (args.named.isEmpty) return;
    for (final named in args.named) {
      for (final param in target.namedParameters) {
        if (_originalVarNames[param] == named.name) {
          named.name = mapping.variables[param]!;
          break;
        }
      }
    }
  }

  @override
  TreeNode visitConstructorInvocation(ConstructorInvocation node) {
    _updateNamedArguments(node.arguments, node.target.function);
    return super.visitConstructorInvocation(node);
  }

  @override
  TreeNode visitStaticInvocation(StaticInvocation node) {
    _updateNamedArguments(node.arguments, node.target.function);
    return super.visitStaticInvocation(node);
  }

  // ---- Call site renames ----

  @override
  TreeNode visitInstanceGet(InstanceGet node) {
    final newName = mapping.members[node.interfaceTarget];
    if (newName != null) node.name = newName;
    return super.visitInstanceGet(node);
  }

  @override
  TreeNode visitInstanceSet(InstanceSet node) {
    final newName = mapping.members[node.interfaceTarget];
    if (newName != null) node.name = newName;
    return super.visitInstanceSet(node);
  }

  @override
  TreeNode visitInstanceInvocation(InstanceInvocation node) {
    final newName = mapping.members[node.interfaceTarget];
    if (newName != null) node.name = newName;
    final target = node.interfaceTarget;
    _updateNamedArguments(node.arguments, target.function);
    return super.visitInstanceInvocation(node);
  }

  @override
  TreeNode visitInstanceTearOff(InstanceTearOff node) {
    final newName = mapping.members[node.interfaceTarget];
    if (newName != null) node.name = newName;
    return super.visitInstanceTearOff(node);
  }

  @override
  TreeNode visitInstanceGetterInvocation(InstanceGetterInvocation node) {
    final newName = mapping.members[node.interfaceTarget];
    if (newName != null) node.name = newName;
    return super.visitInstanceGetterInvocation(node);
  }

  @override
  TreeNode visitSuperPropertyGet(SuperPropertyGet node) {
    final newName = mapping.members[node.interfaceTarget];
    if (newName != null) node.name = newName;
    return super.visitSuperPropertyGet(node);
  }

  @override
  TreeNode visitSuperPropertySet(SuperPropertySet node) {
    final newName = mapping.members[node.interfaceTarget];
    if (newName != null) node.name = newName;
    return super.visitSuperPropertySet(node);
  }

  @override
  TreeNode visitSuperMethodInvocation(SuperMethodInvocation node) {
    final newName = mapping.members[node.interfaceTarget];
    if (newName != null) node.name = newName;
    final target = node.interfaceTarget;
    _updateNamedArguments(node.arguments, target.function);
    return super.visitSuperMethodInvocation(node);
  }
}
