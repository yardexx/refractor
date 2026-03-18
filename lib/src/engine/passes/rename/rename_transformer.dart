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
  late final Map<VariableDeclaration, Expression> _variableInitializers;

  /// Applies the mapping to [component]: transforms the AST and
  /// unbinds canonical names for renamed user libraries.
  void apply(Component component) {
    // Capture original names before any mutations happen.
    _originalVarNames = {
      for (final entry in mapping.variables.entries)
        entry.key: entry.key.name ?? '',
    };
    _variableInitializers = {
      for (final variable in mapping.variables.keys)
        if (variable.initializer != null) variable: variable.initializer!,
    };

    // Build Name → Name lookup from instance-member declarations (before
    // mutation). These names must remain stable for dynamic dispatch.
    final candidates = <Name, Name>{};
    for (final entry in mapping.members.entries) {
      if (!_isDynamicDispatchMember(entry.key)) continue;
      final original = entry.key.name;
      candidates[original] = entry.value;
    }
    _nameMapping = candidates;

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

  @override
  TreeNode visitFunctionInvocation(FunctionInvocation node) {
    final target = _functionTargetFromReceiver(node.receiver);
    if (target != null) {
      _updateNamedArguments(node.arguments, target);
    }
    return super.visitFunctionInvocation(node);
  }

  @override
  TreeNode visitLocalFunctionInvocation(LocalFunctionInvocation node) {
    _updateNamedArguments(node.arguments, node.localFunction.function);
    return super.visitLocalFunctionInvocation(node);
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

  FunctionNode? _functionTargetFromReceiver(Expression receiver) {
    return switch (receiver) {
      StaticTearOff() => receiver.target.function,
      InstanceTearOff() => receiver.interfaceTarget.function,
      ConstructorTearOff() => receiver.function,
      RedirectingFactoryTearOff() => receiver.target.function,
      FunctionExpression() => receiver.function,
      FunctionTearOff() => _functionTargetFromReceiver(receiver.receiver),
      VariableGet() => _functionTargetFromVariable(receiver.variable),
      StaticGet() => _functionTargetFromField(receiver.target),
      _ => null,
    };
  }

  FunctionNode? _functionTargetFromVariable(VariableDeclaration variable) {
    if (!variable.isFinal && !variable.isConst) return null;
    final initializer = _variableInitializers[variable] ?? variable.initializer;
    if (initializer == null) return null;
    return _functionTargetFromReceiver(initializer);
  }

  FunctionNode? _functionTargetFromField(Member member) {
    if (member is! Field) return null;
    if (!member.isFinal && !member.isConst) return null;
    final initializer = member.initializer;
    if (initializer == null) return null;
    return _functionTargetFromReceiver(initializer);
  }

  bool _isDynamicDispatchMember(Member member) {
    return switch (member) {
      Procedure(isStatic: false) => true,
      Field(isStatic: false) => true,
      _ => false,
    };
  }
}
