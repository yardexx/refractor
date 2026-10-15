import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel_toolkit/builder/kernel_builder.dart';
import 'package:refractor/src/engine/pass/transformation/pass_transformer.dart';
import 'package:refractor/src/engine/passes/opaque_predicate/planning/opaque_predicate_plan.dart';
import 'package:refractor/src/engine/passes/opaque_predicate/predicates/opaque_predicate_templates.dart';
import 'package:refractor/src/engine/passes/opaque_predicate/transformation/opaque_predicate_transform_output.dart';

/// Replaces each planned condition `c` with `c && <opaque-true>`, preserving
/// behaviour while making the branch harder to read.
final class OpaquePredicateTransformer
    implements
        PassTransformer<OpaquePredicatePlan, OpaquePredicateTransformOutput> {
  OpaquePredicateTransformer({
    required List<OpaquePredicateTemplate> templates,
  }) : _templates = templates;

  final List<OpaquePredicateTemplate> _templates;

  @override
  Future<OpaquePredicateTransformOutput> apply(
    Component component,
    OpaquePredicatePlan plan,
  ) async {
    if (plan.decisions.isEmpty) {
      return const OpaquePredicateTransformOutput(strengthenedCount: 0);
    }

    final builder = KernelBuilder(component);
    var strengthened = 0;
    for (final decision in plan.decisions) {
      final template = _templates[decision.templateIndex];
      final opaqueTrue = template(builder, decision.constant);
      final site = decision.site;
      site.condition = builder.and(site.condition, opaqueTrue)..parent = site;
      strengthened++;
    }

    return OpaquePredicateTransformOutput(strengthenedCount: strengthened);
  }
}
