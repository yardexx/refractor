import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass/selection/pass_selection.dart';

/// A place a guarded dead-code block can go: insert it at [insertionIndex] in
/// the function body's top-level statements, reading [variable] in the guard.
///
/// [variable] is always in scope and definitely assigned at [insertionIndex] —
/// a parameter (index 0) or a local declared just before it — so the guard
/// reads a live `int` the compiler cannot fold away.
final class DeadCodeSite {
  const DeadCodeSite({
    required this.insertionIndex,
    required this.variable,
  });

  final int insertionIndex;
  final VariableDeclaration variable;
}

/// The functions eligible for a guarded dead-code block, in a stable traversal
/// order, each with the candidate sites its guard can key off.
final class DeadCodeSelection extends PassSelection {
  DeadCodeSelection({
    required List<FunctionNode> orderedFunctions,
    required Map<FunctionNode, List<DeadCodeSite>> sites,
  }) : orderedFunctions = List.unmodifiable(orderedFunctions),
       _sites = Map.unmodifiable(sites);

  final List<FunctionNode> orderedFunctions;
  final Map<FunctionNode, List<DeadCodeSite>> _sites;

  int get selectedFunctionCount => orderedFunctions.length;

  /// The candidate insertion sites for [function], or empty if it is not a
  /// target.
  List<DeadCodeSite> sitesFor(FunctionNode function) =>
      _sites[function] ?? const [];
}

/// Every place in [function] a guarded dead block could be inserted: at the
/// start of the body keyed off an `int` parameter, and after each definitely
/// assigned `int` local keyed off that local. Empty when none apply.
///
/// Locals need a non-null initializer and must not be `late` or `const` — the
/// guard reads the variable right after it comes into scope, so it must already
/// hold a runtime value (an unassigned or `late` local would read null/throw,
/// and a `const` would fold the guard away).
List<DeadCodeSite> deadCodeSites(FunctionNode function) {
  final body = function.body;
  if (body is! Block) {
    return const [];
  }

  final sites = <DeadCodeSite>[];
  for (final parameter in function.positionalParameters) {
    if (_isNonNullableInt(parameter.type)) {
      sites.add(DeadCodeSite(insertionIndex: 0, variable: parameter));
    }
  }

  final statements = body.statements;
  for (var i = 0; i < statements.length; i++) {
    final statement = statements[i];
    if (statement is VariableDeclaration &&
        !statement.isLate &&
        !statement.isConst &&
        statement.initializer != null &&
        _isNonNullableInt(statement.type)) {
      sites.add(DeadCodeSite(insertionIndex: i + 1, variable: statement));
    }
  }
  return sites;
}

/// Whether [function] can carry a guarded dead-code block.
bool isDeadCodeTarget(FunctionNode function) =>
    deadCodeSites(function).isNotEmpty;

bool _isNonNullableInt(DartType type) =>
    type is InterfaceType &&
    type.classNode.name == 'int' &&
    type.nullability == Nullability.nonNullable;
