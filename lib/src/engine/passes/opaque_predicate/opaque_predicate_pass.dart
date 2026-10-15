import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/passes/opaque_predicate/config/opaque_predicate_config.dart';
import 'package:refractor/src/engine/passes/opaque_predicate/planning/opaque_predicate_plan.dart';
import 'package:refractor/src/engine/passes/opaque_predicate/planning/opaque_predicate_planner.dart';
import 'package:refractor/src/engine/passes/opaque_predicate/predicates/opaque_predicate_templates.dart';
import 'package:refractor/src/engine/passes/opaque_predicate/selection/opaque_predicate_selection.dart';
import 'package:refractor/src/engine/passes/opaque_predicate/selection/opaque_predicate_selector.dart';
import 'package:refractor/src/engine/passes/opaque_predicate/transformation/opaque_predicate_transform_output.dart';
import 'package:refractor/src/engine/passes/opaque_predicate/transformation/opaque_predicate_transformer.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

/// Obfuscation pass that strengthens `if` conditions with always-true opaque
/// predicates: each condition `c` becomes `c && <opaque-true>`.
///
/// Behaviour is preserved (the added term is always true), but the branch is
/// harder to reason about, and the predicate differs from site to site because
/// the planner picks a template and constant at random per site.
///
/// Each stage delegates to its own class; the methods below are the seam.
class OpaquePredicatePass
    extends
        StagedPass<
          OpaquePredicateSelection,
          OpaquePredicatePlan,
          OpaquePredicateTransformOutput
        > {
  OpaquePredicatePass({
    required this.config,
    required this.scope,
  });

  final OpaquePredicatePassConfig config;
  final ObfuscationScope scope;

  @override
  String get name => 'opaque_predicate';

  @override
  OpaquePredicateSelection select(Component component) =>
      OpaquePredicateSelector(scope: scope).select(component);

  @override
  Future<OpaquePredicatePlan> plan(
    Component component,
    OpaquePredicateSelection selection,
  ) => OpaquePredicatePlanner(
    seed: config.seed,
    templateCount: opaquePredicateTemplates.length,
    liveTemplateCount: opaquePredicateLiveTemplates.length,
  ).plan(component, selection);

  @override
  Future<OpaquePredicateTransformOutput> transform(
    Component component,
    OpaquePredicatePlan plan,
  ) => OpaquePredicateTransformer(
    templates: opaquePredicateTemplates,
    liveTemplates: opaquePredicateLiveTemplates,
  ).apply(component, plan);

  @override
  PassReport buildReport(
    OpaquePredicateSelection selection,
    OpaquePredicateTransformOutput output,
  ) {
    return PassReport(
      passName: name,
      metadata: output.strengthenedCount == 0
          ? const {}
          : {'conditions_strengthened': '${output.strengthenedCount}'},
    );
  }
}
