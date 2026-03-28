import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/pass/selection/pass_selection.dart';

final class RenameSelection extends PassSelection {
  const RenameSelection({
    required this.classes,
    required this.singletonMembers,
    required this.variables,
    required this.instanceMembersByClass,
  });

  final List<Class> classes;
  final List<Member> singletonMembers;
  final List<VariableDeclaration> variables;
  final Map<Class, List<Member>> instanceMembersByClass;
}
