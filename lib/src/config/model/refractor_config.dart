import 'package:glob/glob.dart';
import 'package:refractor/src/config/model/refractor_settings.dart';
import 'package:refractor/src/engine/pass/config/pass_config.dart';
import 'package:refractor/src/engine/pass/pass_registry.dart';
import 'package:refractor/src/exceptions/refractor_exception.dart';
import 'package:yaml/yaml.dart';

export 'package:refractor/src/config/model/refractor_settings.dart';
export 'package:refractor/src/engine/passes/rename/config/rename_config.dart';
export 'package:refractor/src/engine/passes/string_encrypt/config/string_encrypt_config.dart';

final class RefractorConfig {
  RefractorConfig({
    this.refractor = const RefractorSettings(),
    this.passes = const [],
  });

  factory RefractorConfig.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('exclude')) {
      throw const ConfigException(
        'Global exclude configuration must be nested under '
        '"refractor.exclude".',
      );
    }

    if (json.containsKey('passes')) {
      throw const ConfigException(
        'Pass configuration must be nested under "refractor.passes".',
      );
    }

    final refractorNode = switch (json['refractor']) {
      null => <String, dynamic>{},
      Map() => Map<String, dynamic>.from(json['refractor'] as Map),
      _ => throw const ConfigException(
        '"refractor" must be a YAML mapping/object.',
      ),
    };

    final passJsonNode = refractorNode.remove('passes');
    final passJson = switch (passJsonNode) {
      null => <String, dynamic>{},
      Map() => Map<String, dynamic>.from(passJsonNode),
      _ => throw const ConfigException(
        '"refractor.passes" must be a YAML mapping/object.',
      ),
    };

    return RefractorConfig(
      refractor: RefractorSettings.fromJson(refractorNode),
      passes: defaultPassRegistry.parseAll(passJson),
    );
  }

  /// Parses a YAML string into a [RefractorConfig].
  factory RefractorConfig.fromYaml(String yamlString) {
    if (yamlString.trim().isEmpty) {
      throw const ConfigException('Configuration YAML is empty.');
    }

    try {
      final yaml = loadYaml(yamlString);
      if (yaml == null) {
        throw const ConfigException('Configuration YAML is empty.');
      }

      final json = _yamlToJson(yaml);
      if (json is! Map<String, dynamic>) {
        throw const ConfigException(
          'Configuration root must be a YAML mapping/object.',
        );
      }

      return RefractorConfig.fromJson(json);
    } on ConfigException {
      rethrow;
    } on Object catch (e) {
      throw ConfigException('Invalid configuration YAML.', cause: e);
    }
  }

  final RefractorSettings refractor;
  final List<PassConfig> passes;

  /// Library exclude patterns as [Glob] objects.
  late final List<Glob> excludePatterns = refractor.exclude
      .map(Glob.new)
      .toList();

  /// Convenience getters for backward compatibility with pipeline/proxy code.
  bool get verbose => refractor.verbose;

  String get artifactJsonPath => refractor.artifactJson;
}

/// Recursively converts [YamlMap]/[YamlList] to plain Dart [Map]/[List].
Object? _yamlToJson(Object? node) => switch (node) {
  YamlMap() => node.map((k, v) => MapEntry(k.toString(), _yamlToJson(v))),
  YamlList() => node.map(_yamlToJson).toList(),
  _ => node,
};
