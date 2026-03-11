import 'package:kernel/kernel.dart';

/// A group of members that must share one obfuscated name.
///
/// Members are connected by inheritance — renaming one requires
/// renaming all others to the same name.
class OverrideFamily {
  OverrideFamily({
    required this.members,
    required this.root,
    required this.isPrivate,
    this.libraryScope,
  });

  /// All members in this family.
  final Set<Member> members;

  /// The root member (declared highest in the hierarchy).
  final Member root;

  /// Whether all members are private (determines `_` prefix).
  final bool isPrivate;

  /// Library scope for private families.
  final Library? libraryScope;
}

/// Result of override family analysis — richer than flat `Map<Member, int>`.
class OverrideFamilies {
  OverrideFamilies({
    required this.families,
    required this.familyOf,
  });

  /// Each family is a set of members that must share one name.
  final List<OverrideFamily> families;

  /// Quick lookup: which family does this member belong to?
  final Map<Member, OverrideFamily> familyOf;
}
