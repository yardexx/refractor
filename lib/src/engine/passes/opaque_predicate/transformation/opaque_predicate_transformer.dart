import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel_toolkit/builder/kernel_builder.dart';
import 'package:refractor/src/engine/pass/transformation/pass_transformer.dart';
import 'package:refractor/src/engine/passes/opaque_predicate/planning/opaque_predicate_plan.dart';
import 'package:refractor/src/engine/passes/opaque_predicate/planning/planned_opaque_predicate.dart';
import 'package:refractor/src/engine/passes/opaque_predicate/predicates/opaque_predicate_templates.dart';
import 'package:refractor/src/engine/passes/opaque_predicate/transformation/opaque_predicate_transform_output.dart';

/// Replaces each planned condition `c` with `c && <opaque-true>`, preserving
/// behaviour while making the branch harder to read.
final class OpaquePredicateTransformer
    implements
        PassTransformer<OpaquePredicatePlan, OpaquePredicateTransformOutput> {
  OpaquePredicateTransformer({
    required List<OpaquePredicateTemplate> templates,
    required List<OpaquePredicateLiveTemplate> liveTemplates,
  }) : _templates = templates,
       _liveTemplates = liveTemplates;

  final List<OpaquePredicateTemplate> _templates;
  final List<OpaquePredicateLiveTemplate> _liveTemplates;

  @override
  OpaquePredicateTransformOutput apply(
    Component component,
    OpaquePredicatePlan plan,
  ) {
    if (plan.decisions.isEmpty) {
      return const OpaquePredicateTransformOutput(strengthenedCount: 0);
    }

    final builder = KernelBuilder(component);
    var strengthened = 0;
    for (final decision in plan.decisions) {
      final opaqueTrue = _buildPredicate(decision, builder);
      final site = decision.site;
      site.condition = builder.and(site.condition, opaqueTrue)..parent = site;
      strengthened++;
    }

    return OpaquePredicateTransformOutput(strengthenedCount: strengthened);
  }

  Expression _buildPredicate(
    PlannedOpaquePredicate decision,
    KernelBuilder builder,
  ) {
    final variable = decision.variable;
    if (variable != null) {
      return _liveTemplates[decision.templateIndex](
        builder,
        () => VariableGet(variable),
      );
    }
    return _templates[decision.templateIndex](builder, decision.constant);
  }
}
