import 'package:refractor/src/engine/kernel/helper_source.dart';
import 'package:refractor/src/engine/kernel/runtime_helpers.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/pass/config/pass_config.dart';
import 'package:refractor/src/engine/pass/config/pass_definition.dart';
import 'package:refractor/src/engine/passes/dead_code/config/dead_code_config.dart';
import 'package:refractor/src/engine/passes/dead_code/dead_code_pass.dart';
import 'package:refractor/src/policy/keep_source.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

final class DeadCodeDefinition implements PassDefinition<DeadCodePassConfig> {
  const DeadCodeDefinition();

  @override
  String get name => 'dead_code';

  // Honors glob excludes and @Refractor.keep(): a kept declaration is left
  // untouched. The entry point's name is irrelevant to it.
  @override
  Set<KeepSource> get keepSources => const {
    KeepSource.excludes,
    KeepSource.annotations,
  };

  @override
  Set<HelperSource> get runtimeHelpers => const {};

  @override
  DeadCodePassConfig parseConfig(Map<String, dynamic> json) {
    return DeadCodePassConfig.fromJson(json);
  }

  @override
  Pass createPass({
    required DeadCodePassConfig config,
    required ObfuscationScope scope,
    required RuntimeHelpers helpers,
  }) {
    return DeadCodePass(config: config, scope: scope);
  }

  @override
  bool supports(PassConfig config) => config is DeadCodePassConfig;
}
