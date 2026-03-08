import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/passes/rename/override_family/class_hierarchy.dart';
import 'package:refractor/src/engine/passes/rename/override_family/override_family_analysis.dart';
import 'package:refractor/src/engine/passes/rename/rename_helpers.dart';
import 'package:refractor/src/engine/runner/pass_context.dart';
import 'package:refractor/src/utils/disjoint_set.dart';

/// Analyzes the class hierarchy in a kernel [Component] and groups
/// instance members into override families using Union-Find.
///
/// Two members belong to the same family if they have the same
/// name and their enclosing classes are related by inheritance.
class OverrideFamilyAnalyzer {
  OverrideFamilyAnalysis analyze(Component component, PassContext context) {
    final userClasses = _collectUserClasses(component, context);
    final hierarchy = ClassHierarchy.build(userClasses);
    final memberGroups = _groupInstanceMembersByName(userClasses);
    final singletonMembers = _collectSingletonMembers(
      component,
      context,
      userClasses,
    );

    final uf = DisjointSet<Member>();
    for (final group in memberGroups) {
      final memberName = group.name;
      final pairs = group.members;
      for (var i = 0; i < pairs.length; i++) {
        final (memberA, classA) = pairs[i];
        for (var j = i + 1; j < pairs.length; j++) {
          final (memberB, classB) = pairs[j];
          if (hierarchy.areRelated(classA, classB) ||
              hierarchy.shareDeclaringSupertypeForName(
                classA,
                classB,
                memberName,
              )) {
            uf.union(memberA, memberB);
          }
        }
      }
    }

    return _buildResult(memberGroups, singletonMembers, uf);
  }

  List<Class> _collectUserClasses(Component component, PassContext context) {
    final userClasses = <Class>[];
    for (final lib in component.libraries) {
      if (context.shouldObfuscateLibrary(lib)) {
        userClasses.addAll(lib.classes);
      }
    }
    return userClasses;
  }

  List<_MemberGroup> _groupInstanceMembersByName(List<Class> userClasses) {
    // Group members by (name, library) — private names are library-scoped.
    final groups = <(String, Uri?), _MemberGroup>{};
    for (final cls in userClasses) {
      for (final member in _instanceMembers(cls)) {
        if (_shouldSkip(member)) continue;
        final name = memberNameText(member);
        if (name.isEmpty) continue;
        final isPrivate = name.startsWith('_');
        final scope = isPrivate ? member.enclosingLibrary.importUri : null;
        final key = (name, scope);
        final group = groups[key] ??= _MemberGroup(name);
        group.members.add((member, cls));
      }
    }
    return groups.values.toList();
  }

  List<Member> _collectSingletonMembers(
    Component component,
    PassContext context,
    List<Class> userClasses,
  ) {
    final singletonMembers = <Member>[];
    // Top-level members.
    for (final lib in component.libraries) {
      if (!context.shouldObfuscateLibrary(lib)) continue;
      for (final proc in lib.procedures) {
        if (_shouldSkip(proc)) continue;
        if (proc.name.text.isEmpty) continue;
        singletonMembers.add(proc);
      }
      for (final field in lib.fields) {
        if (_shouldSkip(field)) continue;
        if (field.name.text.isEmpty) continue;
        singletonMembers.add(field);
      }
    }
    // Static class members.
    for (final cls in userClasses) {
      for (final proc in cls.procedures) {
        if (proc.isStatic && !_shouldSkip(proc) && proc.name.text.isNotEmpty) {
          singletonMembers.add(proc);
        }
      }
      for (final field in cls.fields) {
        if (field.isStatic &&
            !_shouldSkip(field) &&
            field.name.text.isNotEmpty) {
          singletonMembers.add(field);
        }
      }
    }
    return singletonMembers;
  }

  OverrideFamilyAnalysis _buildResult(
    List<_MemberGroup> memberGroups,
    List<Member> singletonMembers,
    DisjointSet<Member> uf,
  ) {
    final familyOf = <Member, int>{};
    var nextFamilyId = 0;
    final rootToFamily = <Member, int>{};

    for (final group in memberGroups) {
      for (final (member, _) in group.members) {
        final root = uf.find(member);
        if (!rootToFamily.containsKey(root)) {
          rootToFamily[root] = nextFamilyId++;
        }
        familyOf[member] = rootToFamily[root]!;
      }
    }

    for (final member in singletonMembers) {
      familyOf[member] = nextFamilyId++;
    }

    return OverrideFamilyAnalysis(familyOf: familyOf);
  }

  List<Member> _instanceMembers(Class cls) {
    final members = <Member>[];
    for (final p in cls.procedures) {
      if (!p.isStatic) members.add(p);
    }
    for (final f in cls.fields) {
      if (!f.isStatic) members.add(f);
    }
    members.addAll(cls.constructors);
    return members;
  }

  bool _shouldSkip(Member member) {
    return hasEntryPointPragma(member.annotations);
  }
}

class _MemberGroup {
  _MemberGroup(this.name);

  final String name;
  final List<(Member, Class)> members = [];
}
