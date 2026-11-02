import 'package:refractor/src/engine/kernel/helper_source.dart';
import 'package:refractor/src/engine/kernel/runtime_helpers.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/pass/config/pass_config.dart';
import 'package:refractor/src/engine/pass/config/pass_definition.dart';
import 'package:refractor/src/engine/passes/string_encrypt/config/string_encrypt_config.dart';
import 'package:refractor/src/engine/passes/string_encrypt/runtime/decode_runtime.dart';
import 'package:refractor/src/engine/passes/string_encrypt/string_encrypt_pass.dart';
import 'package:refractor/src/policy/keep_source.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

final class StringEncryptDefinition
    implements PassDefinition<StringEncryptPassConfig> {
  const StringEncryptDefinition();

  @override
  String get name => 'string_encrypt';

  // Honors glob excludes and @Refractor.keep() (a kept declaration is left
  // entirely alone, strings included). It does NOT honor the entry point:
  // keeping main's *name* is a rename concern and says nothing about the
  // string literals inside it, which are fine to encrypt.
  @override
  Set<KeepSource> get keepSources => const {
    KeepSource.excludes,
    KeepSource.annotations,
  };

  // The decode helper, authored as plain Dart (see decode_runtime.dart) and
  // injected once by the engine. The transformer takes it from the injected
  // `RuntimeHelpers` and replaces each plaintext literal with a call to it.
  @override
  Set<HelperSource> get runtimeHelpers => const {
    HelperSource(
      source: decodeRuntimeSource,
      procedureNames: {decodeRuntimeHelperName},
    ),
  };

  @override
  StringEncryptPassConfig parseConfig(Map<String, dynamic> json) {
    return StringEncryptPassConfig.fromJson(json);
  }

  @override
  Pass createPass({
    required StringEncryptPassConfig config,
    required ObfuscationScope scope,
    required RuntimeHelpers helpers,
  }) {
    return StringEncryptPass(config: config, scope: scope, helpers: helpers);
  }

  @override
  bool supports(PassConfig config) => config is StringEncryptPassConfig;
}
