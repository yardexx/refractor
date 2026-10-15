import 'package:refractor/src/engine/kernel/helper_source.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/pass/config/pass_config.dart';
import 'package:refractor/src/policy/keep_source.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

abstract interface class PassDefinition<C extends PassConfig> {
  String get name;

  /// The keep mechanisms this pass honors. Drives keep resolution generically
  /// — the resolver applies exactly these, without knowing the pass.
  Set<KeepSource> get keepSources;

  /// Runtime helpers this pass needs injected into the program. The engine
  /// compiles and injects them once, before passes run; the pass then resolves
  /// the reparented procedures from the component by name. Defaults to none.
  Set<HelperSource> get runtimeHelpers => const {};

  C parseConfig(Map<String, dynamic> json);

  Pass createPass({
    required C config,
    required ObfuscationScope scope,
  });

  bool supports(PassConfig config);
}
