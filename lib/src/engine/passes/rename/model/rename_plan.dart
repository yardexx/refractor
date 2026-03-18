import 'package:kernel/kernel.dart';

class RenamePlan {
  const RenamePlan({
    required this.memberFamilies,
    required this.singletonMembers,
    required this.classes,
    required this.variables,
  });

  final List<MemberFamily> memberFamilies;
  final List<Member> singletonMembers;
  final List<Class> classes;
  final List<VariableDeclaration> variables;
}

class MemberFamily {
  const MemberFamily({
    required this.members,
    required this.originalName,
    this.privacyScope,
  });

  final Set<Member> members;
  final String originalName;
  final Library? privacyScope;
}
