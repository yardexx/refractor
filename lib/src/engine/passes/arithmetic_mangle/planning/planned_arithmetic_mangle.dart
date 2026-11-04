import 'package:kernel/ast.dart';

/// One planned mangle: the [site] to rewrite and the per-site [constant] used
/// by the multiplication identity (ignored by the addition identity).
final class PlannedArithmeticMangle {
  const PlannedArithmeticMangle({
    required this.site,
    required this.constant,
  });

  final InstanceInvocation site;
  final int constant;
}
