import 'package:kernel/ast.dart';

/// Precomputed class hierarchy with direct supertypes, transitive supertypes,
/// and transitive subtypes.
class ClassHierarchy {
  ClassHierarchy._({
    required Map<Class, Set<Class>> allSupertypes,
    required Map<Class, Set<Class>> subtypes,
  })  : _allSupertypes = allSupertypes,
        _subtypes = subtypes;

  factory ClassHierarchy.build(List<Class> userClasses) {
    // Direct supertypes (including SDK/external classes).
    final directSupertypes = <Class, Set<Class>>{};
    for (final cls in userClasses) {
      final supers = <Class>{};
      if (cls.supertype != null) supers.add(cls.supertype!.classNode);
      for (final iface in cls.implementedTypes) {
        supers.add(iface.classNode);
      }
      if (cls.mixedInType != null) supers.add(cls.mixedInType!.classNode);
      directSupertypes[cls] = supers;
    }

    // Transitive supertypes.
    final allSupertypes = <Class, Set<Class>>{};
    for (final cls in userClasses) {
      allSupertypes[cls] = _collectAllSupertypes(cls);
    }

    // Subtypes (reverse graph) — only for user classes.
    final subtypes = <Class, Set<Class>>{};
    for (final cls in userClasses) {
      subtypes.putIfAbsent(cls, () => <Class>{}).add(cls); // self
    }
    for (final cls in userClasses) {
      for (final sup in directSupertypes[cls] ?? const <Class>{}) {
        subtypes.putIfAbsent(sup, () => <Class>{}).add(cls);
      }
    }
    // Transitive closure.
    for (final cls in subtypes.keys.toList()) {
      final visited = <Class>{cls};
      final queue = [...subtypes[cls]!];
      while (queue.isNotEmpty) {
        final current = queue.removeLast();
        if (visited.add(current)) {
          queue.addAll(subtypes[current] ?? const <Class>{});
        }
      }
      subtypes[cls] = visited;
    }

    return ClassHierarchy._(
      allSupertypes: allSupertypes,
      subtypes: subtypes,
    );
  }

  final Map<Class, Set<Class>> _allSupertypes;
  final Map<Class, Set<Class>> _subtypes;

  /// Two classes are related if one is a (transitive) subtype of the other.
  bool areRelated(Class a, Class b) {
    final subsA = _subtypes[a];
    if (subsA != null && subsA.contains(b)) return true;
    final subsB = _subtypes[b];
    if (subsB != null && subsB.contains(a)) return true;
    return false;
  }

  /// Whether [a] and [b] share a common supertype that declares an
  /// overridable member named [memberName].
  bool shareDeclaringSupertypeForName(Class a, Class b, String memberName) {
    final supersA = _allSupertypes[a];
    final supersB = _allSupertypes[b];
    if (supersA == null || supersB == null) return false;

    final common = supersA.intersection(supersB);
    for (final sup in common) {
      if (_declaresOverridableMemberNamed(sup, memberName)) return true;
    }
    return false;
  }

  bool _declaresOverridableMemberNamed(Class cls, String name) {
    for (final p in cls.procedures) {
      if (!p.isStatic && p.name.text == name) return true;
    }
    for (final f in cls.fields) {
      if (!f.isStatic && f.name.text == name) return true;
    }
    return false;
  }

  static Set<Class> _collectAllSupertypes(Class cls, [Set<Class>? seen]) {
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
}
