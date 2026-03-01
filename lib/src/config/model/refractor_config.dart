import 'package:json_annotation/json_annotation.dart';
import 'package:refractor/src/config/converter/pass_config_converter.dart';
import 'package:refractor/src/config/model/pass_config.dart';
import 'package:refractor/src/config/model/refractor_settings.dart';
import 'package:refractor/src/engine/passes/dead_code/dead_code_pass.dart';
import 'package:refractor/src/engine/passes/rename/rename_pass.dart';
import 'package:refractor/src/engine/passes/string_encrypt/string_encrypt_pass.dart';
import 'package:refractor/src/engine/runner/pass.dart';
import 'package:refractor/src/engine/runner/pass_options.dart';
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
    List<PassConfig>? passes,
  }) : passes = passes ?? _defaultPasses();

  factory RefractorConfig.fromJson(Map<String, dynamic> json) =>
      _$RefractorConfigFromJson(json);

  /// Parses a YAML string into a [RefractorConfig].
  factory RefractorConfig.fromYaml(String yamlString) {
    if (yamlString.trim().isEmpty) return RefractorConfig();
    final yaml = loadYaml(yamlString);
    if (yaml == null) return RefractorConfig();

    final json = _yamlToJson(yaml);
    if (json is! Map<String, dynamic>) {
      // It might be a string if you have an empty or invalid yaml like `   \n  `
      return RefractorConfig();
    }
    return RefractorConfig.fromJson(json);
  }

  static List<PassConfig> _defaultPasses() => [
    RenamePassConfig(),
    StringEncryptPassConfig(),
  ];

  final RefractorSettings refractor;
  final List<PassConfig> passes;

  /// Convert this config to [PassOptions] for the obfuscation engine.
  PassOptions toOptions() {
    final renameConfig = passes.whereType<RenamePassConfig>().firstOrNull;
    return PassOptions(
      packageFilter: refractor.packageFilter,
      preserveMain: renameConfig?.preserveMain ?? true,
      excludeNames: renameConfig?.excludeNames.toSet() ?? const {},
      excludePatterns:
          renameConfig?.excludePatterns.map(RegExp.new).toList() ?? const [],
      excludeAnnotations: renameConfig?.excludeAnnotations.toSet() ?? const {},
      verbose: refractor.verbose,
    );
  }

  /// Build a list of [Pass] instances from the configured passes.
  ///
  /// Only enabled passes are included.
  List<Pass> buildPasses() {
    return passes.where((p) => p.enabled).map((p) {
      return switch (p) {
        RenamePassConfig() => RenamePass(),
        StringEncryptPassConfig(:final xorKey) => StringEncryptPass(
          xorKey: xorKey,
        ),
        DeadCodePassConfig(:final maxInsertionsPerProcedure) => DeadCodePass(
          maxInsertionsPerProcedure: maxInsertionsPerProcedure,
        ),
      };
    }).toList();
  }

  /// Convenience getters for backward compatibility with pipeline/proxy code.
  bool get verbose => refractor.verbose;

  String get symbolMapPath => refractor.symbolMap;

  /// Build a pass list from a comma-separated list of pass names.
  ///
  /// Throws [ArgumentError] if an unknown pass name is given.
  static List<Pass> passesFromNames(List<String> names) {
    final available = <String, Pass>{
      'rename': RenamePass(),
      'string_encrypt': StringEncryptPass(),
      'dead_code': DeadCodePass(),
    };
    return names.map((n) {
      final pass = available[n.trim()];
      if (pass == null) throw ConfigException('Unknown pass: "$n"');
      return pass;
    }).toList();
  }
}

/// Recursively converts [YamlMap]/[YamlList] to plain Dart [Map]/[List].
Object? _yamlToJson(Object? node) => switch (node) {
  YamlMap() => node.map((k, v) => MapEntry(k.toString(), _yamlToJson(v))),
  YamlList() => node.map(_yamlToJson).toList(),
  _ => node,
};
