import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass/selection/pass_selection.dart';

/// The `if` conditions eligible for opaque-predicate strengthening, in a stable
/// traversal order.
final class OpaquePredicateSelection extends PassSelection {
  OpaquePredicateSelection({
    required List<IfStatement> orderedSites,
    Map<IfStatement, VariableDeclaration> liveVariables = const {},
  }) : orderedSites = List.unmodifiable(orderedSites),
       _liveVariables = Map.unmodifiable(liveVariables);

  final List<IfStatement> orderedSites;

  /// An in-scope int variable available at a site, if any — used to build a
  /// data-dependent (non-foldable) predicate there.
  final Map<IfStatement, VariableDeclaration> _liveVariables;

  int get selectedSiteCount => orderedSites.length;

  VariableDeclaration? liveVariableFor(IfStatement site) =>
      _liveVariables[site];
}
