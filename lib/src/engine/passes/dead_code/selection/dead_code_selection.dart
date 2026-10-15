import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass/selection/pass_selection.dart';

/// The functions eligible for a guarded dead-code block, in a stable traversal
/// order.
final class DeadCodeSelection extends PassSelection {
  DeadCodeSelection({
    required List<FunctionNode> orderedFunctions,
  }) : orderedFunctions = List.unmodifiable(orderedFunctions);

  final List<FunctionNode> orderedFunctions;

  int get selectedFunctionCount => orderedFunctions.length;
}

/// The first `int` positional parameter of [function], or null.
///
/// The dead block's guard reads a live `int` so the compiler cannot fold it
/// away; a parameter is always in scope at the start of the body, where the
/// block is inserted.
VariableDeclaration? firstIntParam(FunctionNode function) {
  for (final parameter in function.positionalParameters) {
    final type = parameter.type;
    if (type is InterfaceType && type.classNode.name == 'int') {
      return parameter;
    }
  }
  return null;
}

/// Whether [function] can carry a guarded dead-code block: it has a block body
/// and at least one `int` parameter to build the guard from.
bool isDeadCodeTarget(FunctionNode function) =>
    function.body is Block && firstIntParam(function) != null;
