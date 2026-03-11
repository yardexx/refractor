import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_scope.dart';
import 'package:refractor/src/engine/passes/rename/override_family/class_relation_index.dart';
import 'package:refractor/src/engine/passes/rename/override_family/override_families.dart';
import 'package:refractor/src/utils/disjoint_set.dart';
import 'package:refractor/src/utils/rename_helpers.dart';

typedef _ClassMemberPair = (Member, Class);
typedef _MemberKey = (String name, Uri? libraryScope);
typedef _GroupedMembers = Map<_MemberKey, List<_ClassMemberPair>>;

/// Analyzes the class hierarchy and groups instance members into override
/// families using Union-Find.
///
/// Takes already-collected [ClassScope]s and a [ClassRelationIndex].
/// No `Component`, no `ObfuscationTarget`, no singleton collection.
/// Just classes in, families out.
class OverrideFamilyAnalyzer {
  /// Groups instance members into override families.
  OverrideFamilies analyze(
    List<ClassScope> classScopes,
    ClassRelationIndex hierarchy,
  ) {
    final memberGroups = _groupInstanceMembersByName(classScopes);
    final uf = DisjointSet<Member>();

    for (final entry in memberGroups.entries) {
      final (memberName, _) = entry.key;
      final pairs = entry.value;
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

    return _buildFamilies(memberGroups, uf);
  }

  _GroupedMembers _groupInstanceMembersByName(List<ClassScope> classScopes) {
    final groups = <_MemberKey, List<_ClassMemberPair>>{};
    for (final cs in classScopes) {
      for (final member in cs.instanceMembers) {
        final name = memberNameText(member);
        if (name.isEmpty) continue;
        final scope =
            name.startsWith('_') ? member.enclosingLibrary.importUri : null;
        (groups[(name, scope)] ??= <_ClassMemberPair>[])
            .add((member, cs.node));
      }
    }
    return groups;
  }

  OverrideFamilies _buildFamilies(
    _GroupedMembers memberGroups,
    DisjointSet<Member> uf,
  ) {
    final rootToMembers = <Member, Set<Member>>{};

    for (final members in memberGroups.values) {
      for (final (member, _) in members) {
        final root = uf.find(member);
        (rootToMembers[root] ??= <Member>{}).add(member);
      }
    }

    final families = <OverrideFamily>[];
    final familyOf = <Member, OverrideFamily>{};

    for (final entry in rootToMembers.entries) {
      final root = entry.key;
      final members = entry.value;
      final rootName = memberNameText(root);
      final isPrivate = rootName.startsWith('_');
      final family = OverrideFamily(
        members: members,
        root: root,
        isPrivate: isPrivate,
        libraryScope: isPrivate ? root.enclosingLibrary : null,
      );
      families.add(family);
      for (final m in members) {
        familyOf[m] = family;
      }
    }

    return OverrideFamilies(families: families, familyOf: familyOf);
  }
}
