import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_plan.dart';

enum RenameSlotKind {
  family,
  singletonMember,
  classType,
  variable,
}

class RenameSlot {
  const RenameSlot._({
    required this.kind,
    required this.target,
    required this.originalName,
    this.privacyScope,
  });

  factory RenameSlot.family(MemberFamily family) {
    return RenameSlot._(
      kind: RenameSlotKind.family,
      target: family,
      originalName: family.originalName,
      privacyScope: family.privacyScope,
    );
  }

  factory RenameSlot.singletonMember(Member member, String originalName) {
    final isPrivate = originalName.startsWith('_');
    return RenameSlot._(
      kind: RenameSlotKind.singletonMember,
      target: member,
      originalName: originalName,
      privacyScope: isPrivate ? member.enclosingLibrary : null,
    );
  }

  factory RenameSlot.classType(Class cls) {
    return RenameSlot._(
      kind: RenameSlotKind.classType,
      target: cls,
      originalName: cls.name,
    );
  }

  factory RenameSlot.variable(
    VariableDeclaration variable,
    String originalName,
  ) {
    return RenameSlot._(
      kind: RenameSlotKind.variable,
      target: variable,
      originalName: originalName,
    );
  }

  final RenameSlotKind kind;
  final Object target;
  final String originalName;
  final Library? privacyScope;
}
