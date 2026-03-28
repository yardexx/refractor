import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/pass/config/pass_config.dart';
import 'package:refractor/src/engine/pass/config/pass_definition.dart';
import 'package:refractor/src/engine/passes/rename/config/rename_config.dart';
import 'package:refractor/src/engine/passes/rename/rename_pass.dart';
import 'package:refractor/src/policy/resolved_policy.dart';
import 'package:refractor/src/project/project_scope.dart';

final class RenameDefinition implements PassDefinition<RenamePassConfig> {
  const RenameDefinition();

  @override
  String get name => 'rename';

  @override
  RenamePassConfig parseConfig(Map<String, dynamic> json) {
    return RenamePassConfig.fromJson(json);
  }

  @override
  Pass createPass({
    required RenamePassConfig config,
    required ResolvedPolicy policy,
    required ProjectScope projectScope,
  }) {
    return RenamePass(
      config: config,
      policy: policy.rename,
      projectScope: projectScope,
    );
  }

  @override
  bool supports(PassConfig config) => config is RenamePassConfig;
}
