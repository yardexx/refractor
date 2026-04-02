import 'package:kernel/ast.dart';

final class StringEncryptPolicyView {
  const StringEncryptPolicyView({
    Set<Library>? keptLibraries,
    Set<Class>? keptClasses,
    Set<Member>? keptMembers,
    List<RegExp>? excludedLiteralPatterns,
  }) : _keptLibraries = keptLibraries ?? const {},
       _keptClasses = keptClasses ?? const {},
       _keptMembers = keptMembers ?? const {},
       _excludedLiteralPatterns = excludedLiteralPatterns ?? const [];

  final Set<Library> _keptLibraries;
  final Set<Class> _keptClasses;
  final Set<Member> _keptMembers;
  final List<RegExp> _excludedLiteralPatterns;

  bool isLibraryKept(Library library) => _keptLibraries.contains(library);

  bool isClassKept(Class cls) =>
      _keptLibraries.contains(cls.enclosingLibrary) ||
      _keptClasses.contains(cls);

  bool isMemberKept(Member member) =>
      _keptLibraries.contains(member.enclosingLibrary) ||
      (member.enclosingClass != null &&
          _keptClasses.contains(member.enclosingClass)) ||
      _keptMembers.contains(member);

  bool shouldEncryptLiteral(StringLiteral literal) {
    for (final pattern in _excludedLiteralPatterns) {
      if (pattern.hasMatch(literal.value)) {
        return false;
      }
    }
    return true;
  }
}
