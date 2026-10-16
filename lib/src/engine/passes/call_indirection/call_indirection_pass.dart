import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/passes/call_indirection/config/call_indirection_config.dart';
import 'package:refractor/src/engine/passes/call_indirection/planning/call_indirection_plan.dart';
import 'package:refractor/src/engine/passes/call_indirection/planning/call_indirection_planner.dart';
import 'package:refractor/src/engine/passes/call_indirection/selection/call_indirection_selection.dart';
import 'package:refractor/src/engine/passes/call_indirection/selection/call_indirection_selector.dart';
import 'package:refractor/src/engine/passes/call_indirection/transformation/call_indirection_transform_output.dart';
import 'package:refractor/src/engine/passes/call_indirection/transformation/call_indirection_transformer.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

/// Obfuscation pass that routes direct static calls through an injected
/// never-inline forwarder, so the direct call edge is not visible in the
/// binary's call graph.
///
/// `f(a, b)` becomes `refractorCall(f, [a, b]) as R`, where `refractorCall`
/// (marked `vm:never-inline`) dispatches via `Function.apply`. Only non-generic
/// static-method calls with positional-only arguments whose target is in scope
/// are routed; the `Function.apply` forwarding is then exact.
class CallIndirectionPass
    extends
        StagedPass<
          CallIndirectionSelection,
          CallIndirectionPlan,
          CallIndirectionTransformOutput
        > {
  CallIndirectionPass({
    required this.config,
    required this.scope,
  });

  final CallIndirectionPassConfig config;
  final ObfuscationScope scope;

  @override
  String get name => 'call_indirection';

  @override
  CallIndirectionSelection select(Component component) =>
      CallIndirectionSelector(scope: scope).select(component);

  @override
  Future<CallIndirectionPlan> plan(
    Component component,
    CallIndirectionSelection selection,
  ) => const CallIndirectionPlanner().plan(component, selection);

  @override
  Future<CallIndirectionTransformOutput> transform(
    Component component,
    CallIndirectionPlan plan,
  ) => CallIndirectionTransformer(scope: scope).apply(component, plan);

  @override
  PassReport buildReport(
    CallIndirectionSelection selection,
    CallIndirectionTransformOutput output,
  ) {
    return PassReport(
      passName: name,
      metadata: output.indirectedCount == 0
          ? const {}
          : {'calls_indirected': '${output.indirectedCount}'},
    );
  }
}
