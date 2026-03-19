import 'package:refractor/src/config/model/pass_config.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_pass_options.dart';
import 'package:refractor/src/engine/passes/rename/rename_pass.dart';
import 'package:refractor/src/engine/passes/string_encrypt/string_encrypt_pass.dart';
import 'package:refractor/src/engine/runner/pass.dart';

final class PassPipelineBuilder {
  PassPipelineBuilder();

  List<Pass<dynamic>> build(Iterable<PassConfig> configs) {
    final enabledConfigs = configs.where((config) => config.enabled).toList();

    final passes = enabledConfigs.map(_createBuiltInPass).toList();
    return passes;
  }

  Pass<dynamic> _createBuiltInPass(PassConfig config) => switch (config) {
    RenamePassConfig() => RenamePass(
      options: RenamePassOptions(
        preserveMain: config.preserveMain,
        seed: config.seed,
      ),
    ),
    StringEncryptPassConfig() => StringEncryptPass(
      xorKey: config.xorKey,
      excludePatterns: config.excludePatterns.map(RegExp.new).toList(),
    ),
  };

}
