import 'package:refractor/src/config/model/pass_config.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/passes.dart';
import 'package:refractor/src/engine/passes/rename/model.dart';

final class PipelineBuilder {
  PipelineBuilder();

  List<Pass> build(Iterable<PassConfig> configs) {
    final enabledConfigs = configs.where((config) => config.enabled).toList();

    final passes = enabledConfigs.map(_createBuiltInPass).toList();
    return passes;
  }

  Pass _createBuiltInPass(PassConfig config) => switch (config) {
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
