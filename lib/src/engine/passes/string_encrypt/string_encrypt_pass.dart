import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/passes/string_encrypt/config/string_encrypt_config.dart';
import 'package:refractor/src/engine/passes/string_encrypt/planning/string_encrypt_planner.dart';
import 'package:refractor/src/engine/passes/string_encrypt/reporting/string_encrypt_artifact.dart';
import 'package:refractor/src/engine/passes/string_encrypt/selection/string_encrypt_selector.dart';
import 'package:refractor/src/engine/passes/string_encrypt/transformation/string_encrypt_transformer.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

/// Obfuscation pass that replaces plaintext [StringLiteral] nodes with a
/// call to an injected decode helper, so strings are not visible in the binary.
///
/// Encoding: XOR each UTF-8 byte with a fixed key (configurable, default 0x5A).
/// At runtime, the injected `_obfDecode$` reverses this to recover the
/// original string.
class StringEncryptPass extends Pass {
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
  Future<PassResult> run(Component component) async {
    try {
      final selection = StringEncryptSelector(
        scope: scope,
        excludedLiteralPatterns: _excludedLiteralPatterns,
      ).select(component);
      final plan = await StringEncryptPlanner(
        seed: config.seed,
      ).plan(component, selection);

      final output = StringEncryptTransformer(
        scope: scope,
      ).apply(component, plan);
      final transformOutput = await output;

      return PassSucceeded(
        artifact: transformOutput.records.isEmpty
            ? null
            : StringEncryptArtifact(records: transformOutput.records),
        report: PassReport(
          passName: name,
          metadata: transformOutput.encryptedCount == 0
              ? const {}
              : {
                  'strings_encrypted': transformOutput.encryptedCount
                      .toString(),
                },
        ),
      );
    } on Object catch (error) {
      final exception = error is Exception
          ? error
          : Exception(error.toString());
      return PassFailed(
        error: exception,
        report: PassReport(
          passName: name,
          message: error.toString(),
        ),
      );
    }
  }
}
