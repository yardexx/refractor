import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel_toolkit/location/enclosing.dart';
import 'package:refractor/src/engine/kernel_toolkit/relations/class_relations.dart';
import 'package:refractor/src/engine/kernel_toolkit/relations/member_model.dart';
import 'package:refractor/src/engine/pass/selection/pass_selector.dart';
import 'package:refractor/src/engine/passes/rename/selection/rename_selection.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

final class RenameSelector implements PassSelector<RenameSelection> {
  RenameSelector({required ObfuscationScope scope}) : _scope = scope;

  final ObfuscationScope _scope;

  @override
  RenameSelection select(Component component) {
    final collector = _RenameSelectionCollector(scope: _scope);
    component.accept(collector);
    return collector.build();
  }
}

final class _RenameSelectionCollector extends RecursiveVisitor {
  _RenameSelectionCollector({required ObfuscationScope scope}) : _scope = scope;

  final ObfuscationScope _scope;

  final List<Class> _classes = [];
  final List<Member> _singletonMembers = [];
  final List<VariableDeclaration> _variables = [];
  final Map<Class, List<Member>> _instanceMembersByClass = {};

  RenameSelection build() {
    return RenameSelection(
      classes: List.unmodifiable(_classes),
      singletonMembers: List.unmodifiable(_singletonMembers),
      variables: List.unmodifiable(_variables),
      instanceMembersByClass: {
        for (final entry in _instanceMembersByClass.entries)
          entry.key: List.unmodifiable(entry.value),
      },
    );
  }

  @override
  void visitLibrary(Library node) {
    if (!_scope.shouldObfuscateLibrary(node)) {
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
    if (!_scope.shouldObfuscateClass(node)) {
      return;
    }

    final shouldRenameClass = !_isSyntheticMixinClass(node);
    if (shouldRenameClass) {
      _classes.add(node);
    }
    final instanceMembers = <Member>[];
    final externalNames = _externalMemberNames(node);

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
    if (!_scope.shouldObfuscateMember(node)) {
      return;
    }
    super.visitProcedure(node);
  }

  @override
  void visitConstructor(Constructor node) {
    if (!_scope.shouldObfuscateMember(node)) {
      return;
    }
    super.visitConstructor(node);
  }

  @override
  void visitField(Field node) {
    if (!_scope.shouldObfuscateMember(node)) {
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
    return _scope.shouldObfuscateMember(member);
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

    if (!_scope.shouldObfuscateMember(enclosingMember)) {
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

  Set<String> _externalMemberNames(Class cls) {
    final names = <String>{};
    final visited = <Class>{};
    final stack = <Class>[];

    void addSupertypes(Class current) {
      stack.addAll(ClassRelations.directSupertypesOf(current));
    }

    addSupertypes(cls);

    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      if (!visited.add(current)) continue;

      final isProjectLibrary = _scope.isInProject(current.enclosingLibrary);
      if (!isProjectLibrary) {
        for (final procedure in current.procedures) {
          if (!procedure.isStatic) {
            names.add(procedure.name.text);
          }
        }
        for (final field in current.fields) {
          if (!field.isStatic) {
            names.add(field.name.text);
          }
        }
      } else {
        for (final procedure in current.procedures) {
          if (!procedure.isStatic && _scope.keep.isMemberKept(procedure)) {
            names.add(procedure.name.text);
          }
        }
        for (final field in current.fields) {
          if (!field.isStatic && _scope.keep.isMemberKept(field)) {
            names.add(field.name.text);
          }
        }
      }

      addSupertypes(current);
    }

    return names;
  }
}
