import 'package:kernel/kernel.dart';

sealed class RenameNameRequest {
  const RenameNameRequest({
    required this.originalName,
    this.privacyScope,
  });

  final String originalName;
  final Library? privacyScope;
}

final class FamilyRenameNameRequest extends RenameNameRequest {
  const FamilyRenameNameRequest({
    required this.members,
    required super.originalName,
    super.privacyScope,
  });

  final Set<Member> members;
}

final class MemberRenameNameRequest extends RenameNameRequest {
  const MemberRenameNameRequest({
    required this.member,
    required super.originalName,
    super.privacyScope,
  });

  final Member member;
}

final class ClassRenameNameRequest extends RenameNameRequest {
  const ClassRenameNameRequest({
    required this.cls,
    required super.originalName,
  });

  final Class cls;
}

final class VariableRenameNameRequest extends RenameNameRequest {
  const VariableRenameNameRequest({
    required this.variable,
    required super.originalName,
  });

  final VariableDeclaration variable;
}
