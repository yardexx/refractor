import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/passes/string_encrypt/config/string_encrypt_config.dart';
import 'package:refractor/src/engine/passes/string_encrypt/planning/string_encrypt_planner.dart';
import 'package:refractor/src/engine/passes/string_encrypt/reporting/string_encrypt_artifact.dart';
import 'package:refractor/src/engine/passes/string_encrypt/selection/string_encrypt_selector.dart';
import 'package:refractor/src/engine/passes/string_encrypt/transformation/string_encrypt_transformer.dart';
import 'package:refractor/src/policy/string_encrypt_policy_view.dart';
import 'package:refractor/src/project/project_scope.dart';

/// Obfuscation pass that replaces plaintext [StringLiteral] nodes with a
/// call to an injected decode helper, so strings are not visible in the binary.
///
/// Encoding: XOR each UTF-8 byte with a fixed key (configurable, default 0x5A).
/// At runtime, the injected `_obfDecode$` reverses this to recover the
/// original string.
class StringEncryptPass extends Pass {
  StringEncryptPass({
    required this.config,
    required this.policy,
    required this.projectScope,
  });

  final StringEncryptPassConfig config;
  final StringEncryptPolicyView policy;
  final ProjectScope projectScope;

  @override
  String get name => 'string_encrypt';

  @override
  Future<PassResult> run(Component component) async {
    try {
      final selection = StringEncryptSelector(
        projectScope: projectScope,
        policy: policy,
      ).select(component);
      final plan = await StringEncryptPlanner(
        seed: config.xorKey,
      ).plan(component, selection);

      final output = StringEncryptTransformer(
        projectScope: projectScope,
        policy: policy,
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
