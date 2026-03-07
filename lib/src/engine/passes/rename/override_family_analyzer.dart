import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/passes/rename/rename_helpers.dart';
import 'package:refractor/src/engine/runner/pass_context.dart';

/// Result of override family analysis.
class OverrideFamilyAnalysis {
  OverrideFamilyAnalysis({
    required this.familyOf,
    required this.familyClasses,
    required this.subtypesOf,
  });

  /// Maps each member to its override family ID.
  final Map<Member, int> familyOf;

  /// Maps each family ID to the set of classes that declare members in it.
  final Map<int, Set<Class>> familyClasses;

  /// Maps each class to its full subtype closure (all transitive subtypes).
  final Map<Class, Set<Class>> subtypesOf;
}

/// Analyzes the class hierarchy in a kernel [Component] and groups
/// instance members into override families using Union-Find.
///
/// Two members belong to the same family if they have the same
/// name and their enclosing classes are related by inheritance.
class OverrideFamilyAnalyzer {
  OverrideFamilyAnalysis analyze(Component component, PassContext context) {
    // 1. Collect all user-lib classes.
    final userClasses = <Class>[];
    for (final lib in component.libraries) {
      if (context.shouldObfuscateLibrary(lib)) {
        userClasses.addAll(lib.classes);
      }
    }

    // 2. Build supertypes map (direct supertypes including SDK/external
    // classes for override-family checks).
    final supertypesOf = <Class, Set<Class>>{};
    for (final cls in userClasses) {
      final supers = <Class>{};
      if (cls.supertype != null) supers.add(cls.supertype!.classNode);
      for (final iface in cls.implementedTypes) {
        supers.add(iface.classNode);
      }
      if (cls.mixedInType != null) supers.add(cls.mixedInType!.classNode);
      supertypesOf[cls] = supers;
    }
    final allSupertypesOf = <Class, Set<Class>>{};
    for (final cls in userClasses) {
      allSupertypesOf[cls] = _collectAllSupertypes(cls);
    }

    // 3. Compute subtypes (reverse graph) — only for user classes.
    final subtypesOf = <Class, Set<Class>>{};
    for (final cls in userClasses) {
      subtypesOf.putIfAbsent(cls, () => <Class>{}).add(cls); // self
    }
    // Add direct subtype edges.
    for (final cls in userClasses) {
      for (final sup in supertypesOf[cls] ?? const <Class>{}) {
        subtypesOf.putIfAbsent(sup, () => <Class>{}).add(cls);
      }
    }
    // Compute transitive closure via BFS.
    for (final cls in subtypesOf.keys.toList()) {
      final visited = <Class>{cls};
      final queue = [...subtypesOf[cls]!];
      while (queue.isNotEmpty) {
        final current = queue.removeLast();
        if (visited.add(current)) {
          queue.addAll(subtypesOf[current] ?? const <Class>{});
        }
      }
      subtypesOf[cls] = visited;
    }

    // 4. Collect instance members and group by name.
    // Key: member grouping key (private names are library-scoped) →
    // list of (Member, Class) pairs.
    final membersByName = <String, List<(Member, Class)>>{};
    for (final cls in userClasses) {
      for (final member in _instanceMembers(cls)) {
        if (_shouldSkip(member)) continue;
        final key = _memberGroupKey(member);
        if (key == null) continue;
        membersByName.putIfAbsent(key, () => []).add((member, cls));
      }
    }

    // Also collect top-level members and static class members
    // (each becomes its own family).
    final singletonMembers = <Member>[];
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

    // 5. Union-Find to compute families.
    final uf = _UnionFind<Member>();

    for (final entry in membersByName.entries) {
      final nameKey = entry.key;
      final entries = entry.value;
      final memberName = _nameTextFromKey(nameKey);
      // Union members with the same name whose classes are related.
      for (var i = 0; i < entries.length; i++) {
        for (var j = i + 1; j < entries.length; j++) {
          final (_, classA) = entries[i];
          final (_, classB) = entries[j];
          if (_areRelated(classA, classB, subtypesOf) ||
              _shareDeclaringSupertypeForName(
                classA,
                classB,
                memberName,
                allSupertypesOf,
              )) {
            uf.union(entries[i].$1, entries[j].$1);
          }
        }
      }
    }

    // 6. Assign family IDs and build result maps.
    final familyOf = <Member, int>{};
    final familyClasses = <int, Set<Class>>{};
    var nextFamilyId = 0;
    final rootToFamily = <Member, int>{};

    // Instance members.
    for (final entries in membersByName.values) {
      for (final (member, cls) in entries) {
        final root = uf.find(member);
        final familyId = rootToFamily.putIfAbsent(root, () => nextFamilyId++);
        familyOf[member] = familyId;
        familyClasses.putIfAbsent(familyId, () => <Class>{}).add(cls);
      }
    }

    // Singleton members: each gets its own family.
    for (final member in singletonMembers) {
      final familyId = nextFamilyId++;
      familyOf[member] = familyId;
      // No class association for top-level members.
      familyClasses.putIfAbsent(familyId, () => <Class>{});
    }

    return OverrideFamilyAnalysis(
      familyOf: familyOf,
      familyClasses: familyClasses,
      subtypesOf: subtypesOf,
    );
  }

  /// Returns all instance (non-static) members of [cls].
  static List<Member> _instanceMembers(Class cls) {
    final members = <Member>[];
    cls.procedures.where((p) => !p.isStatic).forEach(members.add);
    cls.fields.where((f) => !f.isStatic).forEach(members.add);
    cls.constructors.forEach(members.add);
    return members;
  }

  static bool _shouldSkip(Member member) {
    return hasEntryPointPragma(member.annotations);
  }

  Set<Class> _collectAllSupertypes(Class cls, [Set<Class>? seen]) {
    final visited = seen ?? <Class>{};
    if (!visited.add(cls)) return visited;

    if (cls.supertype != null) {
      _collectAllSupertypes(cls.supertype!.classNode, visited);
    }
    for (final iface in cls.implementedTypes) {
      _collectAllSupertypes(iface.classNode, visited);
    }
    if (cls.mixedInType != null) {
      _collectAllSupertypes(cls.mixedInType!.classNode, visited);
    }
    return visited;
  }

  /// Returns a grouping key for family analysis.
  ///
  /// Private names are library-scoped in Dart, so include library identity
  /// in the key to avoid cross-library family merging.
  static String? _memberGroupKey(Member member) {
    final name = memberNameText(member);
    if (name.isEmpty) return null;
    if (!name.startsWith('_')) return name;
    return '${member.enclosingLibrary.importUri}::$name';
  }

  static String _nameTextFromKey(String key) {
    final idx = key.lastIndexOf('::');
    if (idx == -1) return key;
    return key.substring(idx + 2);
  }

  static bool _declaresOverridableMemberNamed(Class cls, String name) {
    for (final p in cls.procedures) {
      if (!p.isStatic && p.name.text == name) return true;
    }
    for (final f in cls.fields) {
      if (!f.isStatic && f.name.text == name) return true;
    }
    return false;
  }

  static bool _shareDeclaringSupertypeForName(
    Class a,
    Class b,
    String memberName,
    Map<Class, Set<Class>> allSupertypesOf,
  ) {
    final supersA = allSupertypesOf[a];
    final supersB = allSupertypesOf[b];
    if (supersA == null || supersB == null) return false;

    final common = supersA.intersection(supersB);
    for (final sup in common) {
      if (_declaresOverridableMemberNamed(sup, memberName)) {
        return true;
      }
    }
    return false;
  }

  /// Two classes are related if one is a (transitive) subtype of the other.
  static bool _areRelated(
    Class a,
    Class b,
    Map<Class, Set<Class>> subtypesOf,
  ) {
    final subsA = subtypesOf[a];
    if (subsA != null && subsA.contains(b)) return true;
    final subsB = subtypesOf[b];
    if (subsB != null && subsB.contains(a)) return true;
    return false;
  }
}

/// Simple Union-Find (disjoint set) data structure.
class _UnionFind<T> {
  final Map<T, T> _parent = {};
  final Map<T, int> _rank = {};

  T find(T x) {
    _parent.putIfAbsent(x, () => x);
    if (_parent[x] != x) {
      _parent[x] = find(_parent[x] as T);
    }
    return _parent[x] as T;
  }

  void union(T a, T b) {
    final rootA = find(a);
    final rootB = find(b);
    if (rootA == rootB) return;

    final rankA = _rank[rootA] ?? 0;
    final rankB = _rank[rootB] ?? 0;
    if (rankA < rankB) {
      _parent[rootA] = rootB;
    } else if (rankA > rankB) {
      _parent[rootB] = rootA;
    } else {
      _parent[rootB] = rootA;
      _rank[rootA] = rankA + 1;
    }
  }
}
