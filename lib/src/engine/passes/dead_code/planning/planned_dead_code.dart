import 'package:kernel/ast.dart';

/// One planned dead-code insertion: the [function] to prepend a guarded block
/// to, and two constants used to vary the block's junk expressions.
final class PlannedDeadCode {
  const PlannedDeadCode({
    required this.function,
    required this.constantA,
    required this.constantB,
  });

  final FunctionNode function;
  final int constantA;
  final int constantB;
}
