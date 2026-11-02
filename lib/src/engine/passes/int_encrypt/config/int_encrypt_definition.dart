import 'package:refractor/src/engine/kernel/helper_source.dart';
import 'package:refractor/src/engine/kernel/runtime_helpers.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/pass/config/pass_config.dart';
import 'package:refractor/src/engine/pass/config/pass_definition.dart';
import 'package:refractor/src/engine/passes/int_encrypt/config/int_encrypt_config.dart';
import 'package:refractor/src/engine/passes/int_encrypt/int_encrypt_pass.dart';
import 'package:refractor/src/engine/passes/int_encrypt/runtime/int_decode_runtime.dart';
import 'package:refractor/src/policy/keep_source.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

final class IntEncryptDefinition
    implements PassDefinition<IntEncryptPassConfig> {
  const IntEncryptDefinition();

  @override
  String get name => 'int_encrypt';

  // Honors glob excludes and @Refractor.keep() (a kept declaration is left
  // entirely alone, its integers included). The entry point's name is a rename
  // concern and says nothing about the integers inside it.
  @override
  Set<KeepSource> get keepSources => const {
    KeepSource.excludes,
    KeepSource.annotations,
  };

  // The decode helper, authored as plain Dart (see int_decode_runtime.dart) and
  // injected once by the engine. The transformer takes it from the injected
  // `RuntimeHelpers` and replaces each encoded literal with a call to it.
  @override
  Set<HelperSource> get runtimeHelpers => const {
    HelperSource(
      source: intDecodeRuntimeSource,
      procedureNames: {intDecodeRuntimeHelperName},
    ),
  };

  @override
  IntEncryptPassConfig parseConfig(Map<String, dynamic> json) {
    return IntEncryptPassConfig.fromJson(json);
  }

  @override
  Pass createPass({
    required IntEncryptPassConfig config,
    required ObfuscationScope scope,
    required RuntimeHelpers helpers,
  }) {
    return IntEncryptPass(config: config, scope: scope, helpers: helpers);
  }

  @override
  bool supports(PassConfig config) => config is IntEncryptPassConfig;
}
