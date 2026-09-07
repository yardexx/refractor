import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/passes/string_encrypt/config/string_encrypt_config.dart';
import 'package:refractor/src/engine/passes/string_encrypt/planning/string_encrypt_plan.dart';
import 'package:refractor/src/engine/passes/string_encrypt/planning/string_encrypt_planner.dart';
import 'package:refractor/src/engine/passes/string_encrypt/reporting/string_encrypt_artifact.dart';
import 'package:refractor/src/engine/passes/string_encrypt/selection/string_encrypt_selection.dart';
import 'package:refractor/src/engine/passes/string_encrypt/selection/string_encrypt_selector.dart';
import 'package:refractor/src/engine/passes/string_encrypt/transformation/string_encrypt_transform_output.dart';
import 'package:refractor/src/engine/passes/string_encrypt/transformation/string_encrypt_transformer.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

/// Obfuscation pass that replaces plaintext string-literal nodes with a call
/// to an injected decode helper, so strings are not visible in the binary.
///
/// Encoding: XOR each UTF-8 byte with a fixed key (configurable, default 0x5A).
/// At runtime, the injected `_obfDecode$` reverses this to recover the
/// original string.
///
/// No validate stage: the pass asserts no post-mutation invariant of its own
/// beyond kernel verification, so it leaves [validate] at its no-op default.
class StringEncryptPass
    extends
        StagedPass<
          StringEncryptSelection,
          StringEncryptPlan,
          StringEncryptTransformOutput
        > {
  StringEncryptPass({
    required this.config,
    required this.scope,
  }) : _excludedLiteralPatterns = config.excludePatterns
           .map(RegExp.new)
           .toList(growable: false);

  final StringEncryptPassConfig config;
  final ObfuscationScope scope;

  /// Literals matching any of these stay in plaintext. Built from the pass
  /// config — a pass parameter, not a keep policy.
  final List<RegExp> _excludedLiteralPatterns;

  @override
  String get name => 'string_encrypt';

  @override
  StringEncryptSelection select(Component component) => StringEncryptSelector(
    scope: scope,
    excludedLiteralPatterns: _excludedLiteralPatterns,
  ).select(component);

  @override
  Future<StringEncryptPlan> plan(
    Component component,
    StringEncryptSelection selection,
  ) => StringEncryptPlanner(seed: config.seed).plan(component, selection);

  @override
  Future<StringEncryptTransformOutput> transform(
    Component component,
    StringEncryptPlan plan,
  ) => StringEncryptTransformer(scope: scope).apply(component, plan);

  @override
  StringEncryptArtifact? buildArtifact(StringEncryptTransformOutput output) =>
      output.records.isEmpty
      ? null
      : StringEncryptArtifact(records: output.records);

  @override
  PassReport buildReport(
    StringEncryptSelection selection,
    StringEncryptTransformOutput output,
  ) {
    return PassReport(
      passName: name,
      metadata: output.encryptedCount == 0
          ? const {}
          : {'strings_encrypted': output.encryptedCount.toString()},
    );
  }
}
