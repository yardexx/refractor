import 'package:kernel/ast.dart';

/// The set of declarations a single pass must leave untouched.
///
/// This models *keep* only — the user/tooling intent to preserve specific
/// libraries, classes, or members (glob excludes, `@Refractor.keep()`
/// annotations, entry points). It says nothing about project membership;
/// whether a node is even part of the project is a separate, structural
/// concern owned by `ProjectScope` and combined in `ObfuscationScope`.
///
/// A kept container implies its contents are kept: a kept library keeps its
/// classes and members, and a kept class keeps its members.
final class KeepPolicy {
  const KeepPolicy({
    Set<Library> keptLibraries = const {},
    Set<Class> keptClasses = const {},
    Set<Member> keptMembers = const {},
  }) : _keptLibraries = keptLibraries,
       _keptClasses = keptClasses,
       _keptMembers = keptMembers;

  /// A policy that keeps nothing.
  static const KeepPolicy empty = KeepPolicy();

  final Set<Library> _keptLibraries;
  final Set<Class> _keptClasses;
  final Set<Member> _keptMembers;

  bool isLibraryKept(Library library) => _keptLibraries.contains(library);

  bool isClassKept(Class cls) =>
      _keptLibraries.contains(cls.enclosingLibrary) ||
      _keptClasses.contains(cls);

  bool isMemberKept(Member member) =>
      _keptLibraries.contains(member.enclosingLibrary) ||
      (member.enclosingClass != null &&
          _keptClasses.contains(member.enclosingClass)) ||
      _keptMembers.contains(member);
}
