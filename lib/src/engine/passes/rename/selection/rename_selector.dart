import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel_toolkit/location/enclosing.dart';
import 'package:refractor/src/engine/kernel_toolkit/relations/member_model.dart';
import 'package:refractor/src/engine/kernel_toolkit/traversal/scoped_visiting.dart';
import 'package:refractor/src/engine/pass/selection/pass_selector.dart';
import 'package:refractor/src/engine/passes/rename/selection/bound_names.dart';
import 'package:refractor/src/engine/passes/rename/selection/rename_selection.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

final class RenameSelector implements PassSelector<RenameSelection> {
  RenameSelector({required ObfuscationScope scope}) : _scope = scope;

  final ObfuscationScope _scope;

  @override
  RenameSelection select(Component component) {
    final collector = _RenameSelectionCollector(scope: _scope);
    component.accept(collector);
    return collector.build(
      fixedNamesByClass: {
        for (final library in component.libraries)
          if (_scope.isInProject(library))
            for (final cls in library.classes)
              cls: fixedInstanceNamesOf(cls, _scope),
      },
      spelledSelectors: collectSpelledSelectors(component, _scope),
    );
  }
}

final class _RenameSelectionCollector extends RecursiveVisitor
    with ScopedVisiting {
  _RenameSelectionCollector({required this.scope});

  @override
  final ObfuscationScope scope;

  final List<Class> _classes = [];
  final List<Member> _singletonMembers = [];
  final List<VariableDeclaration> _variables = [];
  final Map<Class, List<Member>> _instanceMembersByClass = {};

  RenameSelection build({
    required Map<Class, Set<String>> fixedNamesByClass,
    required Set<Name> spelledSelectors,
  }) {
    return RenameSelection(
      classes: List.unmodifiable(_classes),
      singletonMembers: List.unmodifiable(_singletonMembers),
      variables: List.unmodifiable(_variables),
      instanceMembersByClass: {
        for (final entry in _instanceMembersByClass.entries)
          entry.key: List.unmodifiable(entry.value),
      },
      fixedNamesByClass: fixedNamesByClass,
      spelledSelectors: spelledSelectors,
    );
  }

  @override
  void visitLibrary(Library node) {
    if (!isScopedLibrary(node)) {
      return;
    }

    for (final procedure in node.procedures) {
      if (_isRenameableMember(procedure) && procedure.name.text.isNotEmpty) {
        _singletonMembers.add(procedure);
      }
    }

    for (final field in node.fields) {
      if (_isRenameableMember(field) && field.name.text.isNotEmpty) {
        _singletonMembers.add(field);
      }
    }

    super.visitLibrary(node);
  }

  @override
  void visitClass(Class node) {
    if (!isScopedClass(node)) {
      return;
    }

    final shouldRenameClass = !_isSyntheticMixinClass(node);
    if (shouldRenameClass) {
      _classes.add(node);
    }
    final instanceMembers = <Member>[];
    final externalNames = fixedInstanceNamesOf(node, scope);

    for (final procedure in node.procedures) {
      if (!_isRenameableMember(procedure) ||
          procedure.name.text.isEmpty ||
          (!procedure.isStatic &&
              externalNames.contains(MemberModel.nameText(procedure)))) {
        continue;
      }

      if (procedure.isStatic) {
        _singletonMembers.add(procedure);
      } else {
        instanceMembers.add(procedure);
      }
    }

    for (final field in node.fields) {
      if (!_isRenameableMember(field) ||
          field.name.text.isEmpty ||
          (!field.isStatic &&
              externalNames.contains(MemberModel.nameText(field)))) {
        continue;
      }

      if (field.isStatic) {
        _singletonMembers.add(field);
      } else {
        instanceMembers.add(field);
      }
    }

    for (final constructor in node.constructors) {
      if (!shouldRenameClass) continue;
      if (_isRenameableMember(constructor) &&
          constructor.name.text.isNotEmpty) {
        _singletonMembers.add(constructor);
      }
    }

    _instanceMembersByClass[node] = instanceMembers;
    super.visitClass(node);
  }

  @override
  void visitProcedure(Procedure node) {
    if (!isScopedMember(node)) {
      return;
    }
    super.visitProcedure(node);
  }

  @override
  void visitConstructor(Constructor node) {
    if (!isScopedMember(node)) {
      return;
    }
    super.visitConstructor(node);
  }

  @override
  void visitField(Field node) {
    if (!isScopedMember(node)) {
      return;
    }
    super.visitField(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final name = node.name;
    if (name == null || name.isEmpty) {
      super.visitVariableDeclaration(node);
      return;
    }

    if (_shouldCollectVariable(node)) {
      _variables.add(node);
    }

    super.visitVariableDeclaration(node);
  }

  bool _isRenameableMember(Member member) {
    return isScopedMember(member);
  }

  bool _isSyntheticMixinClass(Class cls) {
    // Preserve compiler-synthesized mixin application classes. Their generated
    // names encode structure the VM still relies on in later transforms.
    return cls.isAnonymousMixin || cls.isEliminatedMixin;
  }

  bool _shouldCollectVariable(VariableDeclaration variable) {
    final enclosingMember = Enclosing.member(variable);
    if (enclosingMember == null) {
      return true;
    }

    if (!isScopedMember(enclosingMember)) {
      return false;
    }

    if (_isDynamicDispatchNamedParameter(variable, enclosingMember)) {
      return false;
    }

    return true;
  }

  bool _isDynamicDispatchNamedParameter(
    VariableDeclaration variable,
    Member enclosingMember,
  ) {
    return switch (enclosingMember) {
      Procedure(isStatic: false) =>
        enclosingMember.function.namedParameters.contains(variable),
      _ => false,
    };
  }
}
