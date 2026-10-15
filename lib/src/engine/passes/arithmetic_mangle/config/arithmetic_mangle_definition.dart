import 'package:refractor/src/engine/kernel/helper_source.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/pass/config/pass_config.dart';
import 'package:refractor/src/engine/pass/config/pass_definition.dart';
import 'package:refractor/src/engine/passes/arithmetic_mangle/arithmetic_mangle_pass.dart';
import 'package:refractor/src/engine/passes/arithmetic_mangle/config/arithmetic_mangle_config.dart';
import 'package:refractor/src/policy/keep_source.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

final class ArithmeticMangleDefinition
    implements PassDefinition<ArithmeticManglePassConfig> {
  const ArithmeticMangleDefinition();

  @override
  String get name => 'arithmetic_mangle';

  // Honors glob excludes and @Refractor.keep(): a kept declaration keeps its
  // arithmetic intact. The entry point's name is irrelevant to it.
  @override
  Set<KeepSource> get keepSources => const {
    KeepSource.excludes,
    KeepSource.annotations,
  };

  @override
  Set<HelperSource> get runtimeHelpers => const {};

  @override
  ArithmeticManglePassConfig parseConfig(Map<String, dynamic> json) {
    return ArithmeticManglePassConfig.fromJson(json);
  }

  @override
  Pass createPass({
    required ArithmeticManglePassConfig config,
    required ObfuscationScope scope,
  }) {
    return ArithmeticManglePass(config: config, scope: scope);
  }

  @override
  bool supports(PassConfig config) => config is ArithmeticManglePassConfig;
}
