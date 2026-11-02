import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/dead_code/selection/dead_code_selection.dart';

/// One planned dead-code insertion: the [function] to insert a guarded block
/// into, the [site] (insertion point + live guard variable) to use, the guard's
/// [mask] and [bound], the junk [steps] the block computes, and the [sink] that
/// consumes the result.
///
/// The guard is `(v & mask) * (v & mask) < -bound`, always false.
final class PlannedDeadCode {
  PlannedDeadCode({
    required this.function,
    required this.site,
    required this.mask,
    required this.bound,
    required List<DeadCodeStep> steps,
    required this.sink,
  }) : steps = List.unmodifiable(steps);

  final FunctionNode function;
  final DeadCodeSite site;
  final int mask;
  final int bound;

  /// Applied in order to a junk temporary seeded from the guard variable. Never
  /// empty.
  final List<DeadCodeStep> steps;
  final DeadCodeSink sink;
}

/// The int operators a junk step may apply.
enum DeadCodeOp { add, sub, mul, xor, and, shl }

/// One junk step: `t = t <op> operand`, where the operand is the guard variable
/// when [usesVariable] is set and the int [constant] otherwise.
final class DeadCodeStep {
  const DeadCodeStep({
    required this.op,
    required this.constant,
    this.usesVariable = false,
  });

  final DeadCodeOp op;
  final int constant;
  final bool usesVariable;
}

/// What the dead block does with its junk value. Each one has an effect the
/// AOT compiler must keep, so the block — and the guard protecting it — survive
/// into machine code; a block of pure, discarded expressions is deleted.
enum DeadCodeSink {
  /// Write the value back into the guard variable, which the live path reads
  /// later. Only for a non-final variable that is read after the site.
  reassign,

  /// Return the value. Only for a synchronous function returning `int`.
  returnValue,

  /// Throw the value. Always available.
  throwValue,
}
