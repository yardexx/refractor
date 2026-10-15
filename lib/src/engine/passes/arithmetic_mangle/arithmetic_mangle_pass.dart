import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/passes/arithmetic_mangle/config/arithmetic_mangle_config.dart';
import 'package:refractor/src/engine/passes/arithmetic_mangle/planning/arithmetic_mangle_plan.dart';
import 'package:refractor/src/engine/passes/arithmetic_mangle/planning/arithmetic_mangle_planner.dart';
import 'package:refractor/src/engine/passes/arithmetic_mangle/selection/arithmetic_mangle_selection.dart';
import 'package:refractor/src/engine/passes/arithmetic_mangle/selection/arithmetic_mangle_selector.dart';
import 'package:refractor/src/engine/passes/arithmetic_mangle/transformation/arithmetic_mangle_transform_output.dart';
import 'package:refractor/src/engine/passes/arithmetic_mangle/transformation/arithmetic_mangle_transformer.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

/// Obfuscation pass that rewrites integer `+` and `*` into equivalent but
/// opaque expressions (e.g. `a + b` becomes `(a ^ b) + ((a & b) << 1)`).
///
/// Operands are bound to temporaries before being reused, so evaluation order
/// and side effects are preserved. The result is identical for two's-complement
/// integers; only the shape of the arithmetic changes.
///
/// Each stage delegates to its own class; the methods below are the seam.
class ArithmeticManglePass
    extends
        StagedPass<
          ArithmeticMangleSelection,
          ArithmeticManglePlan,
          ArithmeticMangleTransformOutput
        > {
  ArithmeticManglePass({
    required this.config,
    required this.scope,
  });

  final ArithmeticManglePassConfig config;
  final ObfuscationScope scope;

  @override
  String get name => 'arithmetic_mangle';

  @override
  ArithmeticMangleSelection select(Component component) =>
      ArithmeticMangleSelector(scope: scope).select(component);

  @override
  Future<ArithmeticManglePlan> plan(
    Component component,
    ArithmeticMangleSelection selection,
  ) => ArithmeticManglePlanner(seed: config.seed).plan(component, selection);

  @override
  Future<ArithmeticMangleTransformOutput> transform(
    Component component,
    ArithmeticManglePlan plan,
  ) => ArithmeticMangleTransformer(scope: scope).apply(component, plan);

  @override
  PassReport buildReport(
    ArithmeticMangleSelection selection,
    ArithmeticMangleTransformOutput output,
  ) {
    return PassReport(
      passName: name,
      metadata: output.mangledCount == 0
          ? const {}
          : {'operations_mangled': '${output.mangledCount}'},
    );
  }
}
