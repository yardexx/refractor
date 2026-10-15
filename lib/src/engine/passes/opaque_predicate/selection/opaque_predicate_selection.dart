import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass/selection/pass_selection.dart';

/// The `if` conditions eligible for opaque-predicate strengthening, in a stable
/// traversal order.
final class OpaquePredicateSelection extends PassSelection {
  OpaquePredicateSelection({
    required List<IfStatement> orderedSites,
  }) : orderedSites = List.unmodifiable(orderedSites);

  final List<IfStatement> orderedSites;

  int get selectedSiteCount => orderedSites.length;
}
