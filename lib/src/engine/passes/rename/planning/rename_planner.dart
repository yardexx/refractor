import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_plan.dart';
import 'package:refractor/src/engine/passes/rename/planning/class_relation_index.dart';
import 'package:refractor/src/engine/policy/obfuscation_policy.dart';
import 'package:refractor/src/utils/disjoint_set.dart';
import 'package:refractor/src/utils/rename_helpers.dart';

class RenamePlanner extends RecursiveVisitor {
  RenamePlanner({required ObfuscationPolicy policy}) : _policy = policy;

  final ObfuscationPolicy _policy;

  final List<Class> _classes = [];
  final List<Member> _singletonMembers = [];
  final List<VariableDeclaration> _variables = [];
  final Map<Class, List<Member>> _instanceMembersByClass = {};

  RenamePlan plan(Component component) {
    _classes.clear();
    _singletonMembers.clear();
    _variables.clear();
    _instanceMembersByClass.clear();

    component.accept(this);
    final memberFamilies = _buildMemberFamilies();
    return RenamePlan(
      memberFamilies: memberFamilies,
      singletonMembers: _singletonMembers,
      classes: _classes,
      variables: _variables,
    );
  }

  @override
  void visitLibrary(Library node) {
    if (_policy.policyForLibrary(node).isRenameExcluded) {
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
    if (_policy.policyForClass(node).isRenameExcluded) {
      return;
    }

    _classes.add(node);
    final instanceMembers = <Member>[];

    for (final procedure in node.procedures) {
      if (!_isRenameableMember(procedure) || procedure.name.text.isEmpty) {
        continue;
      }

      if (procedure.isStatic) {
        _singletonMembers.add(procedure);
      } else {
        instanceMembers.add(procedure);
      }
    }

    for (final field in node.fields) {
      if (!_isRenameableMember(field) || field.name.text.isEmpty) {
        continue;
      }

      if (field.isStatic) {
        _singletonMembers.add(field);
      } else {
        instanceMembers.add(field);
      }
    }

    for (final constructor in node.constructors) {
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
    if (_policy.policyForMember(node).isRenameExcluded) {
      return;
    }
    super.visitProcedure(node);
  }

  @override
  void visitConstructor(Constructor node) {
    if (_policy.policyForMember(node).isRenameExcluded) {
      return;
    }
    super.visitConstructor(node);
  }

  @override
  void visitField(Field node) {
    if (_policy.policyForMember(node).isRenameExcluded) {
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
    return !_policy.policyForMember(member).isRenameExcluded;
  }

  bool _shouldCollectVariable(VariableDeclaration variable) {
    final enclosingMember = _findEnclosingMember(variable);
    if (enclosingMember == null) {
      return true;
    }

    final memberPolicy = _policy.policyForMember(enclosingMember);
    if (memberPolicy.isRenameExcluded) {
      return false;
    }

    if (memberPolicy.excludeParametersFromRename &&
        _isParameter(variable, enclosingMember)) {
      return false;
    }

    if (_isDynamicDispatchNamedParameter(variable, enclosingMember)) {
      return false;
    }

    return true;
  }

  Member? _findEnclosingMember(TreeNode node) {
    var current = node.parent;
    while (current != null) {
      if (current is Member) return current;
      current = current.parent;
    }
    return null;
  }

  bool _isParameter(VariableDeclaration variable, Member enclosingMember) {
    final function = switch (enclosingMember) {
      Procedure() => enclosingMember.function,
      Constructor() => enclosingMember.function,
      _ => null,
    };
    if (function == null) return false;

    return function.positionalParameters.contains(variable) ||
        function.namedParameters.contains(variable);
  }

  bool _isDynamicDispatchNamedParameter(
    VariableDeclaration variable,
    Member enclosingMember,
  ) {
    // Named arguments on instance members must keep their source labels.
    // DynamicInvocation carries only the textual member name, so we can
    // normalize `foo` -> `a` but we cannot soundly retarget `debug:` once the
    // receiver's runtime type is unknown.
    return switch (enclosingMember) {
      Procedure(isStatic: false) =>
        enclosingMember.function.namedParameters.contains(variable),
      _ => false,
    };
  }

  List<MemberFamily> _buildMemberFamilies() {
    final classes = _instanceMembersByClass.keys.toList();
    final hierarchy = ClassRelationIndex.build(classes);
    final grouped = <(String, Uri?), List<(Member, Class)>>{};

    for (final cls in classes) {
      for (final member in _instanceMembersByClass[cls] ?? const <Member>[]) {
        final name = memberNameText(member);
        if (name.isEmpty) continue;
        final privacyScope = name.startsWith('_')
            ? member.enclosingLibrary.importUri
            : null;
        (grouped[(name, privacyScope)] ??= <(Member, Class)>[]).add(
          (member, cls),
        );
      }
    }

    final unionFind = DisjointSet<Member>();
    for (final entry in grouped.entries) {
      final memberName = entry.key.$1;
      final members = entry.value;
      for (var i = 0; i < members.length; i++) {
        final (memberA, classA) = members[i];
        for (var j = i + 1; j < members.length; j++) {
          final (memberB, classB) = members[j];
          if (hierarchy.areRelated(classA, classB) ||
              hierarchy.shareDeclaringSupertypeForName(
                classA,
                classB,
                memberName,
              )) {
            unionFind.union(memberA, memberB);
          }
        }
      }
    }

    final rootToMembers = <Member, Set<Member>>{};
    for (final members in grouped.values) {
      for (final (member, _) in members) {
        final root = unionFind.find(member);
        (rootToMembers[root] ??= <Member>{}).add(member);
      }
    }

    return [
      for (final entry in rootToMembers.entries)
        MemberFamily(
          members: entry.value,
          originalName: memberNameText(entry.key),
          privacyScope: memberNameText(entry.key).startsWith('_')
              ? entry.key.enclosingLibrary
              : null,
        ),
    ];
  }
}
