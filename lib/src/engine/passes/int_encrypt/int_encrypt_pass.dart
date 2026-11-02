import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel/runtime_helpers.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/passes/int_encrypt/config/int_encrypt_config.dart';
import 'package:refractor/src/engine/passes/int_encrypt/planning/int_encrypt_plan.dart';
import 'package:refractor/src/engine/passes/int_encrypt/planning/int_encrypt_planner.dart';
import 'package:refractor/src/engine/passes/int_encrypt/selection/int_encrypt_selection.dart';
import 'package:refractor/src/engine/passes/int_encrypt/selection/int_encrypt_selector.dart';
import 'package:refractor/src/engine/passes/int_encrypt/transformation/int_encrypt_transform_output.dart';
import 'package:refractor/src/engine/passes/int_encrypt/transformation/int_encrypt_transformer.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

/// Obfuscation pass that replaces integer literals with a call to an injected
/// decode helper, so the original magic numbers are not visible in the binary.
///
/// Encoding: XOR the value with a per-literal random key. At runtime the
/// injected `refractorDecodeInt` (marked `vm:never-inline`, so the compiler
/// cannot fold it away) recovers the value. Literals below the configured
/// `minMagnitude` in absolute value, and any literal in a const context, are
/// left alone.
class IntEncryptPass
    extends
        StagedPass<
          IntEncryptSelection,
          IntEncryptPlan,
          IntEncryptTransformOutput
        > {
  IntEncryptPass({
    required this.config,
    required this.scope,
    required this.helpers,
  });

  final IntEncryptPassConfig config;
  final ObfuscationScope scope;
  final RuntimeHelpers helpers;

  @override
  String get name => 'int_encrypt';

  @override
  IntEncryptSelection select(Component component) => IntEncryptSelector(
    scope: scope,
    minMagnitude: config.minMagnitude,
  ).select(component);

  @override
  Future<IntEncryptPlan> plan(
    Component component,
    IntEncryptSelection selection,
  ) => IntEncryptPlanner(seed: config.seed).plan(component, selection);

  @override
  Future<IntEncryptTransformOutput> transform(
    Component component,
    IntEncryptPlan plan,
  ) => IntEncryptTransformer(
    scope: scope,
    helpers: helpers,
  ).apply(component, plan);

  @override
  PassReport buildReport(
    IntEncryptSelection selection,
    IntEncryptTransformOutput output,
  ) {
    return PassReport(
      passName: name,
      metadata: output.encryptedCount == 0
          ? const {}
          : {'ints_encrypted': output.encryptedCount.toString()},
    );
  }
}
