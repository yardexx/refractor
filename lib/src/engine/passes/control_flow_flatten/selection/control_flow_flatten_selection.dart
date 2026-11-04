import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass/selection/pass_selection.dart';

/// The function bodies eligible for control-flow flattening, in a stable
/// traversal order.
final class ControlFlowFlattenSelection extends PassSelection {
  ControlFlowFlattenSelection({
    required List<FunctionNode> orderedFunctions,
  }) : orderedFunctions = List.unmodifiable(orderedFunctions);

  final List<FunctionNode> orderedFunctions;

  int get selectedFunctionCount => orderedFunctions.length;
}

/// Whether [function] is a straight-line body this pass can flatten: a
/// synchronous function whose body is a block of two or more statements, each
/// one a kind the transformer knows how to carry through the state machine.
///
/// Supported statement kinds are expression statements, `return`s, and plain
/// local variable declarations. Declarations are hoisted out of the switch and
/// turned into assignments, so `late` and `const` locals are excluded — their
/// initialization semantics would not survive that rewrite. Any other kind
/// (nested control flow, loops, try/catch) disqualifies the whole body; those
/// are a follow-up.
bool isFlattenableFunction(FunctionNode function) {
  if (function.asyncMarker != AsyncMarker.Sync) {
    return false;
  }
  final body = function.body;
  if (body is! Block || body.statements.length < 2) {
    return false;
  }
  return body.statements.every(isFlattenableStatement);
}

/// Whether [statement] is a top-level body statement the transformer supports.
bool isFlattenableStatement(Statement statement) {
  return switch (statement) {
    ExpressionStatement() => true,
    ReturnStatement() => true,
    VariableDeclaration(:final isLate, :final isConst) => !isLate && !isConst,
    _ => false,
  };
}
