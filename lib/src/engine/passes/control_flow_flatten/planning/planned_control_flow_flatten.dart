import 'package:kernel/ast.dart';

/// One planned flattening: the [function] to rewrite and the order its cases
/// are laid out in (a permutation of the block indices). Execution order is
/// preserved by the continue links regardless of layout.
final class PlannedControlFlowFlatten {
  const PlannedControlFlowFlatten({
    required this.function,
    required this.layout,
  });

  final FunctionNode function;
  final List<int> layout;
}
