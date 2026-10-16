import 'package:json_annotation/json_annotation.dart';

part 'refractor_settings.g.dart';

@JsonSerializable(
  checked: true,
  disallowUnrecognizedKeys: true,
  fieldRename: FieldRename.snake,
  createToJson: false,
)
final class RefractorSettings {
  const RefractorSettings({
    this.artifactJson = 'build_artifacts.json',
    this.symbolMap = 'symbol_map.json',
    this.exclude = const [],
    this.verbose = false,
  });

  factory RefractorSettings.fromJson(Map<String, dynamic> json) =>
      _$RefractorSettingsFromJson(json);

  final String artifactJson;

  /// Output path for the stable, versioned symbol map used to deobfuscate
  /// stack traces. Relative paths resolve under the build directory. Written
  /// only when the rename pass produced a mapping.
  final String symbolMap;

  final List<String> exclude;
  final bool verbose;

  RefractorSettings copyWith({
    String? artifactJson,
    String? symbolMap,
    List<String>? exclude,
    bool? verbose,
  }) {
    return RefractorSettings(
      artifactJson: artifactJson ?? this.artifactJson,
      symbolMap: symbolMap ?? this.symbolMap,
      exclude: exclude ?? this.exclude,
      verbose: verbose ?? this.verbose,
    );
  }
}
