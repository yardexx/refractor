import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/dead_code/selection/dead_code_selection.dart';

/// One planned dead-code insertion: the [function] to insert a guarded block
/// into, the [site] (insertion point + live guard variable) to use, and two
/// constants used to vary the block's junk expressions.
final class PlannedDeadCode {
  const PlannedDeadCode({
    required this.function,
    required this.site,
    required this.constantA,
    required this.constantB,
  });

  final FunctionNode function;
  final DeadCodeSite site;
  final int constantA;
  final int constantB;
}
