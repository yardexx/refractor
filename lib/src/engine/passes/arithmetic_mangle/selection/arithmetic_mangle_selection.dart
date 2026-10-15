import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass/selection/pass_selection.dart';

/// The integer `+` and `*` invocations eligible for mangling, in a stable
/// traversal order.
final class ArithmeticMangleSelection extends PassSelection {
  ArithmeticMangleSelection({
    required List<InstanceInvocation> orderedSites,
  }) : orderedSites = List.unmodifiable(orderedSites);

  final List<InstanceInvocation> orderedSites;

  int get selectedSiteCount => orderedSites.length;
}
