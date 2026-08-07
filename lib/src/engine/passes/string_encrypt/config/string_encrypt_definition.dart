import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/pass/config/pass_config.dart';
import 'package:refractor/src/engine/pass/config/pass_definition.dart';
import 'package:refractor/src/engine/passes/string_encrypt/config/string_encrypt_config.dart';
import 'package:refractor/src/engine/passes/string_encrypt/string_encrypt_pass.dart';
import 'package:refractor/src/policy/keep_source.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

final class StringEncryptDefinition
    implements PassDefinition<StringEncryptPassConfig> {
  const StringEncryptDefinition();

  @override
  String get name => 'string_encrypt';

  // String encryption rewrites literals, not identifiers, so annotation and
  // entry-point keeps (which preserve names) do not apply — only excludes.
  @override
  Set<KeepSource> get keepSources => const {KeepSource.excludes};

  @override
  StringEncryptPassConfig parseConfig(Map<String, dynamic> json) {
    return StringEncryptPassConfig.fromJson(json);
  }

  @override
  Pass createPass({
    required StringEncryptPassConfig config,
    required ObfuscationScope scope,
  }) {
    return StringEncryptPass(config: config, scope: scope);
  }

  @override
  bool supports(PassConfig config) => config is StringEncryptPassConfig;
}
