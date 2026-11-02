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

/// Whether the dead block at [site] may write its junk back into the guard
/// variable: the variable is assignable and the live path reads it after the
/// site, so the compiler must keep the write. A later write anywhere in the
/// body could make ours dead, so any later write rules it out.
bool canReassign(FunctionNode function, DeadCodeSite site) {
  final variable = site.variable;
  if (variable.isFinal || variable.isConst || variable.isLate) {
    return false;
  }
  final statements = (function.body! as Block).statements;
  final finder = _ReadFinder(variable);
  for (var i = site.insertionIndex; i < statements.length; i++) {
    statements[i].accept(finder);
  }
  return finder.read && !finder.written;
}

/// Whether the dead block may `return` an `int` from [function].
bool canReturnInt(FunctionNode function) =>
    function.asyncMarker == AsyncMarker.Sync &&
    _isNonNullableInt(function.returnType);

/// Whether [function] can carry a guarded dead-code block.
bool isDeadCodeTarget(FunctionNode function) =>
    deadCodeSites(function).isNotEmpty;

bool _isNonNullableInt(DartType type) =>
    type is InterfaceType &&
    type.classNode.name == 'int' &&
    type.nullability == Nullability.nonNullable;

final class _ReadFinder extends RecursiveVisitor {
  _ReadFinder(this.variable);

  final VariableDeclaration variable;
  bool read = false;
  bool written = false;

  @override
  void visitVariableGet(VariableGet node) {
    if (node.variable == variable) {
      read = true;
    }
  }

  @override
  void visitVariableSet(VariableSet node) {
    if (node.variable == variable) {
      written = true;
    }
    super.visitVariableSet(node);
  }
}
