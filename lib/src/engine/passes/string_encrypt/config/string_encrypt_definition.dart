import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/pass/config/pass_config.dart';
import 'package:refractor/src/engine/pass/config/pass_definition.dart';
import 'package:refractor/src/engine/passes/string_encrypt/config/string_encrypt_config.dart';
import 'package:refractor/src/engine/passes/string_encrypt/string_encrypt_pass.dart';
import 'package:refractor/src/policy/resolved_policy.dart';
import 'package:refractor/src/project/project_scope.dart';

final class StringEncryptDefinition
    implements PassDefinition<StringEncryptPassConfig> {
  const StringEncryptDefinition();

  @override
  String get name => 'string_encrypt';

  @override
  StringEncryptPassConfig parseConfig(Map<String, dynamic> json) {
    return StringEncryptPassConfig.fromJson(json);
  }

  @override
  Pass createPass({
    required StringEncryptPassConfig config,
    required ResolvedPolicy policy,
    required ProjectScope projectScope,
  }) {
    return StringEncryptPass(
      config: config,
      policy: policy.stringEncrypt,
      projectScope: projectScope,
    );
  }

  @override
  bool supports(PassConfig config) => config is StringEncryptPassConfig;
}
