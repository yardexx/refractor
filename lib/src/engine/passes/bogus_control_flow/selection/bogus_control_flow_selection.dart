import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass/selection/pass_selection.dart';

/// The functions eligible for a bogus branch, in a stable traversal order, each
/// with the parameters its always-true guard can key off.
final class BogusControlFlowSelection extends PassSelection {
  BogusControlFlowSelection({
    required List<FunctionNode> orderedFunctions,
    required Map<FunctionNode, List<VariableDeclaration>> guardCandidates,
  }) : orderedFunctions = List.unmodifiable(orderedFunctions),
       _guardCandidates = Map.identity()..addAll(guardCandidates);

  final List<FunctionNode> orderedFunctions;
  final Map<FunctionNode, List<VariableDeclaration>> _guardCandidates;

  int get selectedFunctionCount => orderedFunctions.length;

  List<VariableDeclaration> guardCandidatesFor(FunctionNode function) =>
      _guardCandidates[function] ?? const [];
}

/// The non-nullable `int` parameters of [function] that can key the opaque
/// guard. A parameter is in scope for the whole body, where the branch is
/// inserted, and is a runtime value the guard cannot be folded against.
List<VariableDeclaration> bogusGuardCandidates(FunctionNode function) {
  return [
    for (final parameter in function.positionalParameters)
      if (_isNonNullableInt(parameter.type)) parameter,
    for (final parameter in function.namedParameters)
      if (_isNonNullableInt(parameter.type)) parameter,
  ];
}

/// Whether [function] can carry a bogus branch: a synchronous function whose
/// body is a non-empty block of at most [maxStatements] top-level statements,
/// with a non-nullable `int` parameter to key the always-true guard from.
///
/// The body is cloned into the never-executed branch, so [maxStatements] bounds
/// the code-size cost. Async bodies are excluded to stay clear of the backend's
/// async rewriting.
bool isBogusControlFlowTarget(
  FunctionNode function, {
  required int maxStatements,
}) {
  if (function.asyncMarker != AsyncMarker.Sync) {
    return false;
  }
  final body = function.body;
  if (body is! Block) {
    return false;
  }
  if (body.statements.isEmpty || body.statements.length > maxStatements) {
    return false;
  }
  return bogusGuardCandidates(function).isNotEmpty;
}

bool _isNonNullableInt(DartType type) =>
    type is InterfaceType &&
    type.classNode.name == 'int' &&
    type.nullability == Nullability.nonNullable;
