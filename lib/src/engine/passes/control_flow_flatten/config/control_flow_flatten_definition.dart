import 'package:refractor/src/engine/kernel/helper_source.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/pass/config/pass_config.dart';
import 'package:refractor/src/engine/pass/config/pass_definition.dart';
import 'package:refractor/src/engine/passes/control_flow_flatten/config/control_flow_flatten_config.dart';
import 'package:refractor/src/engine/passes/control_flow_flatten/control_flow_flatten_pass.dart';
import 'package:refractor/src/policy/keep_source.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

final class ControlFlowFlattenDefinition
    implements PassDefinition<ControlFlowFlattenPassConfig> {
  const ControlFlowFlattenDefinition();

  @override
  String get name => 'control_flow_flatten';

  // Honors glob excludes and @Refractor.keep(): a kept declaration keeps its
  // control flow intact. The entry point's name is irrelevant to it.
  @override
  Set<KeepSource> get keepSources => const {
    KeepSource.excludes,
    KeepSource.annotations,
  };

  @override
  Set<HelperSource> get runtimeHelpers => const {};

  @override
  ControlFlowFlattenPassConfig parseConfig(Map<String, dynamic> json) {
    return ControlFlowFlattenPassConfig.fromJson(json);
  }

  @override
  Pass createPass({
    required ControlFlowFlattenPassConfig config,
    required ObfuscationScope scope,
  }) {
    return ControlFlowFlattenPass(config: config, scope: scope);
  }

  @override
  bool supports(PassConfig config) => config is ControlFlowFlattenPassConfig;
}
