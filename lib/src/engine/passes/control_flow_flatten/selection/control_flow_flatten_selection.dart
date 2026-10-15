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

/// Whether [function] is a straight-line body this prototype can flatten: a
/// synchronous function whose body is a block of two or more statements, all
/// expression statements.
///
/// Restricting to expression statements keeps the first version safe — there
/// are no local declarations to rescope, no returns or control flow to
/// reorder. Those cases are a follow-up.
bool isFlattenableFunction(FunctionNode function) {
  if (function.asyncMarker != AsyncMarker.Sync) {
    return false;
  }
  final body = function.body;
  if (body is! Block || body.statements.length < 2) {
    return false;
  }
  return body.statements.every((statement) => statement is ExpressionStatement);
}
