import 'package:refractor/src/engine/kernel/helper_source.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/pass/config/pass_config.dart';
import 'package:refractor/src/engine/pass/config/pass_definition.dart';
import 'package:refractor/src/engine/passes/call_indirection/call_indirection_pass.dart';
import 'package:refractor/src/engine/passes/call_indirection/config/call_indirection_config.dart';
import 'package:refractor/src/engine/passes/call_indirection/runtime/call_indirection_runtime.dart';
import 'package:refractor/src/policy/keep_source.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

final class CallIndirectionDefinition
    implements PassDefinition<CallIndirectionPassConfig> {
  const CallIndirectionDefinition();

  @override
  String get name => 'call_indirection';

  // Honors glob excludes and @Refractor.keep(): a kept call site keeps its
  // direct call, and calls to a kept target are left direct (selection checks
  // the target is in scope). The entry point's name is irrelevant to it.
  @override
  Set<KeepSource> get keepSources => const {
    KeepSource.excludes,
    KeepSource.annotations,
  };

  @override
  Set<HelperSource> get runtimeHelpers => const {
    HelperSource(
      source: callIndirectionRuntimeSource,
      procedureNames: {callIndirectionHelperName},
    ),
  };

  @override
  CallIndirectionPassConfig parseConfig(Map<String, dynamic> json) {
    return CallIndirectionPassConfig.fromJson(json);
  }

  @override
  Pass createPass({
    required CallIndirectionPassConfig config,
    required ObfuscationScope scope,
  }) {
    return CallIndirectionPass(config: config, scope: scope);
  }

  @override
  bool supports(PassConfig config) => config is CallIndirectionPassConfig;
}
