import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/pass/config/pass_config.dart';
import 'package:refractor/src/engine/pass/config/pass_definition.dart';
import 'package:refractor/src/engine/passes/rename/config/rename_definition.dart';
import 'package:refractor/src/engine/passes/string_encrypt/config/string_encrypt_definition.dart';
import 'package:refractor/src/engine/passes/virtualize/config/virtualize_definition.dart';
import 'package:refractor/src/exceptions/refractor_exception.dart';
import 'package:refractor/src/policy/resolved_policy.dart';
import 'package:refractor/src/project/project_scope.dart';

const defaultPassRegistry = PassRegistry([
  RenameDefinition(),
  StringEncryptDefinition(),
  VirtualizeDefinition(),
]);

final class PassRegistry {
  const PassRegistry(this.definitions);

  final List<PassDefinition<dynamic>> definitions;

  List<PassConfig> parseAll(Map<String, dynamic> json) {
    return [
      for (final entry in json.entries)
        parse(entry.key, _normalizePassConfigValue(entry.key, entry.value)),
    ];
  }

  PassConfig parse(String name, Map<String, dynamic> json) {
    final definition = definitions.where(
      (definition) => definition.name == name,
    );
    if (definition.isEmpty) {
      throw ConfigException('Unknown pass type: $name');
    }
    return definition.single.parseConfig(json) as PassConfig;
  }

  List<Pass> createAll({
    required Iterable<PassConfig> configs,
    required ResolvedPolicy policy,
    required ProjectScope projectScope,
  }) {
    return [
      for (final config in configs)
        if (config.enabled)
          _definitionFor(config).createPass(
            config: config,
            policy: policy,
            projectScope: projectScope,
          ),
    ];
  }

  PassDefinition<dynamic> _definitionFor(PassConfig config) {
    final matches = definitions.where(
      (definition) => definition.supports(config),
    );
    if (matches.isEmpty) {
      throw StateError('No pass definition found for ${config.runtimeType}.');
    }
    return matches.single;
  }
}

Map<String, dynamic> normalizePassConfigValue(String name, Object? value) {
  return switch (value) {
    true => <String, dynamic>{},
    false => <String, dynamic>{'enabled': false},
    Map() => Map<String, dynamic>.from(value),
    _ => throw ConfigException('Invalid config for pass "$name": $value'),
  };
}

Map<String, dynamic> _normalizePassConfigValue(String name, Object? value) {
  return normalizePassConfigValue(name, value);
}
