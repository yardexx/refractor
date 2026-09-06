import 'package:kernel/ast.dart';

/// Precomputed class relations for a bounded class scope.
///
/// - Supertypes include external classes reachable through inheritance.
/// - Subtypes are limited to classes present in the provided class scope.
class ClassRelationIndex {
  ClassRelationIndex._({
    required Map<Class, Set<Class>> allSupertypes,
    required Map<Class, Set<Class>> allSubtypes,
  }) : _allSupertypes = allSupertypes,
       _allSubtypes = allSubtypes;

  factory ClassRelationIndex.build(Iterable<Class> classScope) {
    final scope = classScope.toSet();

    final directSupertypes = _collectAllDirectSupertypes(scope);
    final allSupertypes = _collectAllTransitiveSupertypes(scope);
    final directSubtypes = _collectDirectSubtypes(scope, directSupertypes);
    final allSubtypes = _collectAllTransitiveSubtypes(scope, directSubtypes);

    return ClassRelationIndex._(
      allSupertypes: allSupertypes,
      allSubtypes: allSubtypes,
    );
  }

  final Map<Class, Set<Class>> _allSupertypes;
  final Map<Class, Set<Class>> _allSubtypes;

  Set<Class> supertypesOf(Class cls) => _allSupertypes[cls] ?? const <Class>{};

  Set<Class> subtypesOf(Class cls) => _allSubtypes[cls] ?? const <Class>{};

  bool areRelated(Class a, Class b) {
    final subsA = _allSubtypes[a];
    if (subsA != null && subsA.contains(b)) return true;
    final subsB = _allSubtypes[b];
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

  static Set<Class> _collectDirectSupertypes(Class cls) {
    final supertypes = <Class>{};
    if (cls.supertype != null) supertypes.add(cls.supertype!.classNode);
    for (final iface in cls.implementedTypes) {
      supertypes.add(iface.classNode);
    }
    if (cls.mixedInType != null) supertypes.add(cls.mixedInType!.classNode);
    return supertypes;
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

  static Map<Class, Set<Class>> _collectAllDirectSupertypes(Set<Class> scope) {
    final directSupertypes = <Class, Set<Class>>{};
    for (final cls in scope) {
      directSupertypes[cls] = _collectDirectSupertypes(cls);
    }
    return directSupertypes;
  }

  static Map<Class, Set<Class>> _collectDirectSubtypes(
    Set<Class> scope,
    Map<Class, Set<Class>> directSupertypes,
  ) {
    final directSubtypes = <Class, Set<Class>>{};
    for (final cls in scope) {
      directSubtypes[cls] = <Class>{};
    }
    for (final cls in scope) {
      for (final sup in directSupertypes[cls] ?? const <Class>{}) {
        if (scope.contains(sup)) {
          directSubtypes[sup]!.add(cls);
        }
      }
    }
    return directSubtypes;
  }

  static Map<Class, Set<Class>> _collectAllTransitiveSupertypes(
    Set<Class> scope,
  ) {
    final allSupertypes = <Class, Set<Class>>{};
    for (final cls in scope) {
      allSupertypes[cls] = _collectTransitiveSupertypes(cls);
    }
    return allSupertypes;
  }

  static Set<Class> _collectTransitiveSupertypes(Class root) {
    final visited = <Class>{};
    final stack = <Class>[];

    if (root.supertype != null) stack.add(root.supertype!.classNode);
    for (final iface in root.implementedTypes) {
      stack.add(iface.classNode);
    }
    if (root.mixedInType != null) stack.add(root.mixedInType!.classNode);

    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      if (!visited.add(current)) continue;

      if (current.supertype != null) stack.add(current.supertype!.classNode);
      for (final iface in current.implementedTypes) {
        stack.add(iface.classNode);
      }
      if (current.mixedInType != null) {
        stack.add(current.mixedInType!.classNode);
      }
    }

    return visited;
  }

  static Set<Class> _collectTransitiveSubtypes(
    Class root,
    Map<Class, Set<Class>> directSubtypes,
  ) {
    final visited = <Class>{root};
    final stack = <Class>[...(directSubtypes[root] ?? const <Class>{})];

    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      if (!visited.add(current)) continue;
      stack.addAll(directSubtypes[current] ?? const <Class>{});
    }

    return visited;
  }

  static Map<Class, Set<Class>> _collectAllTransitiveSubtypes(
    Set<Class> scope,
    Map<Class, Set<Class>> directSubtypes,
  ) {
    final allSubtypes = <Class, Set<Class>>{};
    for (final cls in scope) {
      allSubtypes[cls] = _collectTransitiveSubtypes(cls, directSubtypes);
    }
    return allSubtypes;
  }
}
