import 'package:refractor/src/engine/kernel/helper_source.dart';
import 'package:refractor/src/engine/kernel/runtime_helpers.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/pass/config/pass_config.dart';
import 'package:refractor/src/engine/pass/config/pass_definition.dart';
import 'package:refractor/src/engine/passes/bogus_control_flow/bogus_control_flow_pass.dart';
import 'package:refractor/src/engine/passes/bogus_control_flow/config/bogus_control_flow_config.dart';
import 'package:refractor/src/policy/keep_source.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

final class BogusControlFlowDefinition
    implements PassDefinition<BogusControlFlowPassConfig> {
  const BogusControlFlowDefinition();

  @override
  String get name => 'bogus_control_flow';

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
  BogusControlFlowPassConfig parseConfig(Map<String, dynamic> json) {
    return BogusControlFlowPassConfig.fromJson(json);
  }

  @override
  Pass createPass({
    required BogusControlFlowPassConfig config,
    required ObfuscationScope scope,
    required RuntimeHelpers helpers,
  }) {
    return BogusControlFlowPass(config: config, scope: scope);
  }

  @override
  bool supports(PassConfig config) => config is BogusControlFlowPassConfig;
}
