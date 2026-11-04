import 'package:kernel/ast.dart';

/// One planned strengthening at [site]. When [variable] is set, [templateIndex]
/// selects a live template built from that variable; otherwise it selects a
/// constant template built from [constant].
final class PlannedOpaquePredicate {
  const PlannedOpaquePredicate({
    required this.site,
    required this.templateIndex,
    required this.constant,
    this.variable,
  });

  final IfStatement site;
  final int templateIndex;
  final int constant;
  final VariableDeclaration? variable;
}
