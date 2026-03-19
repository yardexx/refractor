import 'package:glob/glob.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:refractor/src/config/converter/pass_config_converter.dart';
import 'package:refractor/src/config/model/pass_config.dart';
import 'package:refractor/src/config/model/refractor_settings.dart';
import 'package:refractor/src/exceptions/refractor_exception.dart';
import 'package:yaml/yaml.dart';

export 'package:refractor/src/config/converter/pass_config_converter.dart';
export 'package:refractor/src/config/model/pass_config.dart';
export 'package:refractor/src/config/model/refractor_settings.dart';

part 'refractor_config.g.dart';

@JsonSerializable(
  checked: true,
  fieldRename: FieldRename.snake,
  createToJson: false,
  converters: [PassConfigListConverter()],
)
final class RefractorConfig {
  RefractorConfig({
    this.refractor = const RefractorSettings(),
    this.passes = const [],
  });

  factory RefractorConfig.fromJson(Map<String, dynamic> json) =>
      _$RefractorConfigFromJson(json);

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

  String get symbolMapPath => refractor.symbolMap;
}

/// Recursively converts [YamlMap]/[YamlList] to plain Dart [Map]/[List].
Object? _yamlToJson(Object? node) => switch (node) {
  YamlMap() => node.map((k, v) => MapEntry(k.toString(), _yamlToJson(v))),
  YamlList() => node.map(_yamlToJson).toList(),
  _ => node,
};
