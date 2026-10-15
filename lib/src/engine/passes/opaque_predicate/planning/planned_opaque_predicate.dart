import 'package:kernel/ast.dart';

/// One planned strengthening: which template to apply at [site], and the
/// per-site constant to build it from.
final class PlannedOpaquePredicate {
  const PlannedOpaquePredicate({
    required this.site,
    required this.templateIndex,
    required this.constant,
  });

  final IfStatement site;
  final int templateIndex;
  final int constant;
}
