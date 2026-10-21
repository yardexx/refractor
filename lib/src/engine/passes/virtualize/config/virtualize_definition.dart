import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/pass/config/pass_config.dart';
import 'package:refractor/src/engine/pass/config/pass_definition.dart';
import 'package:refractor/src/engine/passes/virtualize/config/virtualize_config.dart';
import 'package:refractor/src/engine/passes/virtualize/virtualize_pass.dart';
import 'package:refractor/src/policy/resolved_policy.dart';
import 'package:refractor/src/project/project_scope.dart';

final class VirtualizeDefinition
    implements PassDefinition<VirtualizePassConfig> {
  const VirtualizeDefinition();

  @override
  String get name => 'virtualize';

  @override
  VirtualizePassConfig parseConfig(Map<String, dynamic> json) {
    return VirtualizePassConfig.fromJson(json);
  }

  @override
  Pass createPass({
    required VirtualizePassConfig config,
    required ResolvedPolicy policy,
    required ProjectScope projectScope,
  }) {
    return VirtualizePass(config: config, projectScope: projectScope);
  }

  @override
  bool supports(PassConfig config) => config is VirtualizePassConfig;
}
