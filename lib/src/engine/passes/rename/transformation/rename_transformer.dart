import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel_toolkit/naming.dart';
import 'package:refractor/src/engine/kernel_toolkit/relations/member_model.dart';
import 'package:refractor/src/engine/kernel_toolkit/traversal/scoped_transformer.dart';
import 'package:refractor/src/engine/pass/transformation/pass_transformer.dart';
import 'package:refractor/src/engine/passes/rename/planning/rename_plan.dart';
import 'package:refractor/src/engine/passes/rename/reporting/rename_artifact.dart';
import 'package:refractor/src/engine/passes/rename/reporting/rename_mapping.dart';
import 'package:refractor/src/engine/passes/rename/transformation/rename_transform_output.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

class RenameTransformer
    implements PassTransformer<RenamePlan, RenameTransformOutput> {
  RenameTransformer({
    required ObfuscationScope scope,
  }) : _scope = scope;

  final ObfuscationScope _scope;

  @override
  Future<RenameTransformOutput> apply(
    Component component,
    RenamePlan plan,
  ) async {
    final visitor = _RenameTransformVisitor(
      scope: _scope,
      mapping: plan.mapping,
    );
    component.transformChildren(visitor);
    for (final lib in component.libraries) {
      if (_scope.isInProject(lib)) {
        lib.reference.canonicalName?.unbindAll();
      }
    }

    return RenameTransformOutput(
      renamedClasses: visitor.renamedClasses,
      renamedMembers: visitor.renamedMembers,
      renamedVariables: visitor.renamedVariables,
      artifact: RenameArtifact(mapping: plan.mapping),
    );
  }
}

final class _RenameTransformVisitor extends ScopedKernelTransformer {
  _RenameTransformVisitor({
    required super.scope,
    required RenameMapping mapping,
  }) : _mapping = mapping,
       _originalVarNames = {
         for (final entry in mapping.variables.entries)
           entry.key: entry.key.name ?? '',
       },
       _variableInitializers = {
         for (final variable in mapping.variables.keys)
           if (variable.initializer != null) variable: variable.initializer!,
       },
       _nameMapping = _buildDynamicNameMapping(mapping);

  final RenameMapping _mapping;

  /// Original names of renamed variables, captured before mutation.
  /// Used to match [NamedExpression]s at call sites to renamed parameters.
  final Map<VariableDeclaration, String> _originalVarNames;

  /// Maps the original [Name] of a member to its obfuscated [Name].
  ///
  /// Built before any mutations so that dynamic call sites
  /// ([DynamicGet], [DynamicSet], [DynamicInvocation]) can look up
  /// the new name even though they have no `interfaceTarget`.
  final Map<Name, Name> _nameMapping;
  final Map<VariableDeclaration, Expression> _variableInitializers;

  int renamedClasses = 0;
  int renamedMembers = 0;
  int renamedVariables = 0;

  static Map<Name, Name> _buildDynamicNameMapping(RenameMapping mapping) {
    final candidates = <Name, Name>{};
    for (final entry in mapping.members.entries) {
      if (!MemberModel.isInstanceDispatch(entry.key)) continue;
      candidates[entry.key.name] = entry.value;
    }
    return candidates;
  }

  @override
  TreeNode visitClass(Class node) {
    final obf = _mapping.classes[node];
    if (obf != null && node.name != obf) {
      node.name = obf;
      renamedClasses++;
    }
    return super.visitClass(node);
  }

  @override
  TreeNode visitProcedure(Procedure node) {
    final newName = _mapping.members[node];
    if (newName != null && !KernelNames.same(node.name, newName)) {
      node.name = newName;
      renamedMembers++;
    }
    return super.visitProcedure(node);
  }

  @override
  TreeNode visitField(Field node) {
    final newName = _mapping.members[node];
    if (newName != null && !KernelNames.same(node.name, newName)) {
      node.name = newName;
      renamedMembers++;
    }
    return super.visitField(node);
  }

  @override
  TreeNode visitConstructor(Constructor node) {
    final newName = _mapping.members[node];
    if (newName != null && !KernelNames.same(node.name, newName)) {
      node.name = newName;
      renamedMembers++;
    }
    return super.visitConstructor(node);
  }

  @override
  TreeNode visitVariableDeclaration(VariableDeclaration node) {
    final newName = _mapping.variables[node];
    if (newName != null && node.name != newName) {
      node.name = newName;
      renamedVariables++;
    }
    return super.visitVariableDeclaration(node);
  }

  void _updateNamedArguments(Arguments args, FunctionNode target) {
    if (args.named.isEmpty) return;
    for (final named in args.named) {
      for (final param in target.namedParameters) {
        if (_originalVarNames[param] == named.name) {
          named.name = _mapping.variables[param]!;
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

  @override
  TreeNode visitInstanceGet(InstanceGet node) {
    final newName = _mapping.members[node.interfaceTarget];
    if (newName != null) node.name = newName;
    return super.visitInstanceGet(node);
  }

  @override
  TreeNode visitInstanceSet(InstanceSet node) {
    final newName = _mapping.members[node.interfaceTarget];
    if (newName != null) node.name = newName;
    return super.visitInstanceSet(node);
  }

  @override
  TreeNode visitInstanceInvocation(InstanceInvocation node) {
    final newName = _mapping.members[node.interfaceTarget];
    if (newName != null) node.name = newName;
    _updateNamedArguments(node.arguments, node.interfaceTarget.function);
    return super.visitInstanceInvocation(node);
  }

  @override
  TreeNode visitInstanceTearOff(InstanceTearOff node) {
    final newName = _mapping.members[node.interfaceTarget];
    if (newName != null) node.name = newName;
    return super.visitInstanceTearOff(node);
  }

  @override
  TreeNode visitInstanceGetterInvocation(InstanceGetterInvocation node) {
    final newName = _mapping.members[node.interfaceTarget];
    if (newName != null) node.name = newName;
    return super.visitInstanceGetterInvocation(node);
  }

  @override
  TreeNode visitSuperPropertyGet(SuperPropertyGet node) {
    final newName = _mapping.members[node.interfaceTarget];
    if (newName != null) node.name = newName;
    return super.visitSuperPropertyGet(node);
  }

  @override
  TreeNode visitSuperPropertySet(SuperPropertySet node) {
    final newName = _mapping.members[node.interfaceTarget];
    if (newName != null) node.name = newName;
    return super.visitSuperPropertySet(node);
  }

  @override
  TreeNode visitSuperMethodInvocation(SuperMethodInvocation node) {
    final newName = _mapping.members[node.interfaceTarget];
    if (newName != null) node.name = newName;
    _updateNamedArguments(node.arguments, node.interfaceTarget.function);
    return super.visitSuperMethodInvocation(node);
  }

  @override
  TreeNode visitAbstractSuperPropertyGet(AbstractSuperPropertyGet node) {
    final newName = _mapping.members[node.interfaceTarget];
    if (newName != null) node.name = newName;
    return super.visitAbstractSuperPropertyGet(node);
  }

  @override
  TreeNode visitAbstractSuperPropertySet(AbstractSuperPropertySet node) {
    final newName = _mapping.members[node.interfaceTarget];
    if (newName != null) node.name = newName;
    return super.visitAbstractSuperPropertySet(node);
  }

  @override
  TreeNode visitAbstractSuperMethodInvocation(
    AbstractSuperMethodInvocation node,
  ) {
    final newName = _mapping.members[node.interfaceTarget];
    if (newName != null) node.name = newName;
    _updateNamedArguments(node.arguments, node.interfaceTarget.function);
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
      Instantiation() => _functionTargetFromReceiver(receiver.expression),
      VariableGet() => _functionTargetFromVariable(
        receiver.variable,
        <VariableDeclaration>{},
        <Field>{},
      ),
      StaticGet() => _functionTargetFromField(
        receiver.target,
        <VariableDeclaration>{},
        <Field>{},
      ),
      _ => null,
    };
  }

  FunctionNode? _functionTargetFromVariable(
    VariableDeclaration variable,
    Set<VariableDeclaration> seenVariables,
    Set<Field> seenFields,
  ) {
    if (!variable.isFinal && !variable.isConst) return null;
    if (!seenVariables.add(variable)) return null;
    final initializer = _variableInitializers[variable] ?? variable.initializer;
    if (initializer == null) return null;
    return _functionTargetFromAliasedReceiver(
      initializer,
      seenVariables,
      seenFields,
    );
  }

  FunctionNode? _functionTargetFromField(
    Member member,
    Set<VariableDeclaration> seenVariables,
    Set<Field> seenFields,
  ) {
    if (member is! Field) return null;
    if (!member.isFinal && !member.isConst) return null;
    if (!seenFields.add(member)) return null;
    final initializer = member.initializer;
    if (initializer == null) return null;
    return _functionTargetFromAliasedReceiver(
      initializer,
      seenVariables,
      seenFields,
    );
  }

  FunctionNode? _functionTargetFromAliasedReceiver(
    Expression receiver,
    Set<VariableDeclaration> seenVariables,
    Set<Field> seenFields,
  ) {
    return switch (receiver) {
      VariableGet() => _functionTargetFromVariable(
        receiver.variable,
        seenVariables,
        seenFields,
      ),
      StaticGet() => _functionTargetFromField(
        receiver.target,
        seenVariables,
        seenFields,
      ),
      FunctionTearOff() => _functionTargetFromAliasedReceiver(
        receiver.receiver,
        seenVariables,
        seenFields,
      ),
      Instantiation() => _functionTargetFromAliasedReceiver(
        receiver.expression,
        seenVariables,
        seenFields,
      ),
      _ => _functionTargetFromReceiver(receiver),
    };
  }
}
