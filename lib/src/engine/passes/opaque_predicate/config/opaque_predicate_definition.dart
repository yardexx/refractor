import 'package:refractor/src/engine/kernel/helper_source.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/pass/config/pass_config.dart';
import 'package:refractor/src/engine/pass/config/pass_definition.dart';
import 'package:refractor/src/engine/passes/opaque_predicate/config/opaque_predicate_config.dart';
import 'package:refractor/src/engine/passes/opaque_predicate/opaque_predicate_pass.dart';
import 'package:refractor/src/policy/keep_source.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

final class OpaquePredicateDefinition
    implements PassDefinition<OpaquePredicatePassConfig> {
  const OpaquePredicateDefinition();

  @override
  String get name => 'opaque_predicate';

  // Honors glob excludes and @Refractor.keep(): a kept declaration keeps its
  // control flow intact. It does not touch the entry point's name, so it does
  // not honor that keep source.
  @override
  Set<KeepSource> get keepSources => const {
    KeepSource.excludes,
    KeepSource.annotations,
  };

  @override
  Set<HelperSource> get runtimeHelpers => const {};

  @override
  OpaquePredicatePassConfig parseConfig(Map<String, dynamic> json) {
    return OpaquePredicatePassConfig.fromJson(json);
  }

  @override
  Pass createPass({
    required OpaquePredicatePassConfig config,
    required ObfuscationScope scope,
  }) {
    return OpaquePredicatePass(config: config, scope: scope);
  }

  @override
  bool supports(PassConfig config) => config is OpaquePredicatePassConfig;
}
