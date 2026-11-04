import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass/planning/pass_plan.dart';

/// The static calls to route through the forwarder, identified by node
/// identity.
final class CallIndirectionPlan extends PassPlan {
  CallIndirectionPlan({
    required Iterable<StaticInvocation> sites,
  }) : _sites = Set.identity()..addAll(sites);

  final Set<StaticInvocation> _sites;

  int get plannedSiteCount => _sites.length;

  bool contains(StaticInvocation site) => _sites.contains(site);
}
