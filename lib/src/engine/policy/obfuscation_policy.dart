import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/policy/declaration_policy.dart';

class ObfuscationPolicy {
  ObfuscationPolicy({
    Map<Library, DeclarationPolicy>? libraryPolicies,
    Map<Class, DeclarationPolicy>? classPolicies,
    Map<Member, DeclarationPolicy>? memberPolicies,
  }) : _libraryPolicies = libraryPolicies ?? const {},
       _classPolicies = classPolicies ?? const {},
       _memberPolicies = memberPolicies ?? const {};

  final Map<Library, DeclarationPolicy> _libraryPolicies;
  final Map<Class, DeclarationPolicy> _classPolicies;
  final Map<Member, DeclarationPolicy> _memberPolicies;

  DeclarationPolicy policyForLibrary(Library library) {
    return _libraryPolicies[library] ?? DeclarationPolicy.allow;
  }

  DeclarationPolicy policyForClass(Class cls) {
    final libraryPolicy = policyForLibrary(cls.enclosingLibrary);
    final classPolicy = _classPolicies[cls] ?? DeclarationPolicy.allow;
    return libraryPolicy.merge(classPolicy);
  }

  DeclarationPolicy policyForMember(Member member) {
    final libraryPolicy = policyForLibrary(member.enclosingLibrary);
    final classPolicy = member.enclosingClass == null
        ? DeclarationPolicy.allow
        : (_classPolicies[member.enclosingClass!] ?? DeclarationPolicy.allow);
    final memberPolicy = _memberPolicies[member] ?? DeclarationPolicy.allow;
    return libraryPolicy.merge(classPolicy).merge(memberPolicy);
  }
}
