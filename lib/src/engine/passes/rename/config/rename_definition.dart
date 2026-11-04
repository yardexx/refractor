import 'package:refractor/src/engine/kernel/helper_source.dart';
import 'package:refractor/src/engine/kernel/runtime_helpers.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/pass/config/pass_config.dart';
import 'package:refractor/src/engine/pass/config/pass_definition.dart';
import 'package:refractor/src/engine/passes/rename/config/rename_config.dart';
import 'package:refractor/src/engine/passes/rename/rename_pass.dart';
import 'package:refractor/src/policy/keep_source.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

final class RenameDefinition implements PassDefinition<RenamePassConfig> {
  const RenameDefinition();

  @override
  String get name => 'rename';

  // Rename preserves identifiers, so it honors every keep mechanism.
  @override
  Set<KeepSource> get keepSources => const {
    KeepSource.excludes,
    KeepSource.annotations,
    KeepSource.entryPoint,
  };

  // Rename rewrites existing declarations; it injects no runtime code.
  @override
  Set<HelperSource> get runtimeHelpers => const {};

  @override
  RenamePassConfig parseConfig(Map<String, dynamic> json) {
    return RenamePassConfig.fromJson(json);
  }

  @override
  Pass createPass({
    required RenamePassConfig config,
    required ObfuscationScope scope,
    required RuntimeHelpers helpers,
  }) {
    return RenamePass(config: config, scope: scope);
  }

  @override
  bool supports(PassConfig config) => config is RenamePassConfig;
}
