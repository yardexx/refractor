import 'package:kernel/ast.dart';

/// The kind of a kernel [Member].
enum MemberKind { procedure, field, constructor }

/// Classification helpers for kernel [Member]s.
///
/// Namespaced statics so call sites read `MemberModel.nameText(m)` — the
/// member-kind knowledge lives in one place instead of being re-derived
/// per pass.
final class MemberModel {
  const MemberModel._();

  /// The declared name text of [member].
  static String nameText(Member member) => switch (member) {
    final Procedure p => p.name.text,
    final Field f => f.name.text,
    final Constructor c => c.name.text,
  };

  /// The [MemberKind] of [member].
  static MemberKind kind(Member member) => switch (member) {
    Procedure() => MemberKind.procedure,
    Field() => MemberKind.field,
    Constructor() => MemberKind.constructor,
  };

  /// A lowercase label for [member]'s kind, or null when [member] is null.
  /// Used in reporting records.
  static String? kindLabel(Member? member) => switch (member) {
    Procedure() => 'procedure',
    Field() => 'field',
    Constructor() => 'constructor',
    _ => null,
  };

  /// Whether [member] participates in instance dispatch — a non-static
  /// [Procedure] or [Field]. Static members and constructors do not.
  static bool isInstanceDispatch(Member member) => switch (member) {
    Procedure(isStatic: false) => true,
    Field(isStatic: false) => true,
    _ => false,
  };
}
