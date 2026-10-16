import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass/selection/pass_selection.dart';

final class CallIndirectionSelection extends PassSelection {
  CallIndirectionSelection({
    required List<StaticInvocation> orderedSites,
  }) : _orderedSites = List.unmodifiable(orderedSites),
       _sites = Set.identity()..addAll(orderedSites);

  final List<StaticInvocation> _orderedSites;
  final Set<StaticInvocation> _sites;

  int get selectedSiteCount => _sites.length;
  List<StaticInvocation> get orderedSites => _orderedSites;

  bool contains(StaticInvocation site) => _sites.contains(site);
}

/// Whether [node] is a direct static call this pass can route through the
/// forwarder: it targets a non-generic static method with only positional
/// arguments. Those constraints keep the `Function.apply` forwarding exact —
/// no named arguments to reassemble and no type arguments to carry.
bool isIndirectableCall(StaticInvocation node) {
  final target = node.target;
  if (target.kind != ProcedureKind.Method || !target.isStatic) {
    return false;
  }
  if (target.function.typeParameters.isNotEmpty) {
    return false;
  }
  final arguments = node.arguments;
  return arguments.named.isEmpty && arguments.types.isEmpty;
}
