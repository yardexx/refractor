import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/pass/selection/pass_selection.dart';

final class RenameSelection extends PassSelection {
  const RenameSelection({
    required this.classes,
    required this.singletonMembers,
    required this.variables,
    required this.instanceMembersByClass,
    this.fixedNamesByClass = const {},
    this.spelledSelectors = const {},
  });

  final List<Class> classes;
  final List<Member> singletonMembers;
  final List<VariableDeclaration> variables;
  final Map<Class, List<Member>> instanceMembersByClass;

  /// For every project class (kept and excluded ones included), the instance
  /// member names it must keep. See `fixedInstanceNamesOf`.
  final Map<Class, Set<String>> fixedNamesByClass;

  /// Selectors referred to by spelling where rename cannot rewrite them. See
  /// `collectSpelledSelectors`.
  final Set<Name> spelledSelectors;
}
