import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/passes/rename/override_family/override_families.dart';

/// Structured snapshot of everything the allocator needs to produce names.
///
/// Output of the collection phase — contains all declarations that should
/// be renamed, grouped by category.
class RenameScope {
  const RenameScope({
    required this.overrideFamilies,
    required this.classScopes,
    required this.topLevelMembers,
    required this.variables,
  });

  /// Override families — groups of members that must share one name.
  final OverrideFamilies overrideFamilies;

  /// Classes with their members, preserving the class→member relationship.
  final List<ClassScope> classScopes;

  /// Top-level procedures and fields (not in any class).
  final List<Member> topLevelMembers;

  /// Variables (locals + parameters) to rename.
  final List<VariableDeclaration> variables;
}

/// A class with its members grouped by category.
class ClassScope {
  const ClassScope({
    required this.node,
    this.instanceMembers = const [],
    this.staticMembers = const [],
    this.constructors = const [],
  });

  final Class node;
  final List<Member> instanceMembers;
  final List<Member> staticMembers;
  final List<Constructor> constructors;
}
