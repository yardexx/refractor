import 'package:kernel/ast.dart';

enum MemberKind { procedure, field, constructor }

final class MemberModel {
  const MemberModel._();

  static String nameText(Member member) => switch (member) {
    final Procedure p => p.name.text,
    final Field f => f.name.text,
    final Constructor c => c.name.text,
  };

  static MemberKind kind(Member member) => switch (member) {
    Procedure() => MemberKind.procedure,
    Field() => MemberKind.field,
    Constructor() => MemberKind.constructor,
  };

  static String? kindLabel(Member? member) => switch (member) {
    Procedure() => 'procedure',
    Field() => 'field',
    Constructor() => 'constructor',
    _ => null,
  };

  static bool isInstanceDispatch(Member member) => switch (member) {
    Procedure(isStatic: false) => true,
    Field(isStatic: false) => true,
    _ => false,
  };
}
