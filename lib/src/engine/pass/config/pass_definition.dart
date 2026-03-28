import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/pass/config/pass_config.dart';
import 'package:refractor/src/policy/resolved_policy.dart';
import 'package:refractor/src/project/project_scope.dart';

abstract interface class PassDefinition<C extends PassConfig> {
  String get name;

  C parseConfig(Map<String, dynamic> json);

  Pass createPass({
    required C config,
    required ResolvedPolicy policy,
    required ProjectScope projectScope,
  });

  bool supports(PassConfig config);
}
