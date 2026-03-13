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

  /// Maps the original [Name] of a member to its obfuscated [Name].
  ///
  /// Built before any mutations so that dynamic call sites
  /// ([DynamicGet], [DynamicSet], [DynamicInvocation]) can look up
  /// the new name even though they have no `interfaceTarget`.
  late final Map<Name, Name> _nameMapping;

  /// Applies the mapping to [component]: transforms the AST and
  /// unbinds canonical names for renamed user libraries.
  void apply(Component component) {
    // Capture original names before any mutations happen.
    _originalVarNames = {
      for (final entry in mapping.variables.entries)
        entry.key: entry.key.name ?? '',
    };

    // Build Name → Name lookup from member declarations (before mutation).
    _nameMapping = {
      for (final entry in mapping.members.entries) entry.key.name: entry.value,
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

  // ---- Call site renames (statically resolved) ----

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

  // ---- Call site renames (abstract super — mixin declarations) ----

  @override
  TreeNode visitAbstractSuperPropertyGet(AbstractSuperPropertyGet node) {
    final newName = mapping.members[node.interfaceTarget];
    if (newName != null) node.name = newName;
    return super.visitAbstractSuperPropertyGet(node);
  }

  @override
  TreeNode visitAbstractSuperPropertySet(AbstractSuperPropertySet node) {
    final newName = mapping.members[node.interfaceTarget];
    if (newName != null) node.name = newName;
    return super.visitAbstractSuperPropertySet(node);
  }

  @override
  TreeNode visitAbstractSuperMethodInvocation(
    AbstractSuperMethodInvocation node,
  ) {
    final newName = mapping.members[node.interfaceTarget];
    if (newName != null) node.name = newName;
    final target = node.interfaceTarget;
    _updateNamedArguments(node.arguments, target.function);
    return super.visitAbstractSuperMethodInvocation(node);
  }

  // ---- Call site renames (dynamic dispatch) ----

  @override
  TreeNode visitDynamicGet(DynamicGet node) {
    final newName = _nameMapping[node.name];
    if (newName != null) node.name = newName;
    return super.visitDynamicGet(node);
  }

  @override
  TreeNode visitDynamicSet(DynamicSet node) {
    final newName = _nameMapping[node.name];
    if (newName != null) node.name = newName;
    return super.visitDynamicSet(node);
  }

  @override
  TreeNode visitDynamicInvocation(DynamicInvocation node) {
    final newName = _nameMapping[node.name];
    if (newName != null) node.name = newName;
    return super.visitDynamicInvocation(node);
  }
}
