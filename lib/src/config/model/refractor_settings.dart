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
    this.exclude = const [],
    this.verbose = false,
  });

  factory RefractorSettings.fromJson(Map<String, dynamic> json) =>
      _$RefractorSettingsFromJson(json);

  final String artifactJson;
  final List<String> exclude;
  final bool verbose;

  RefractorSettings copyWith({
    String? artifactJson,
    List<String>? exclude,
    bool? verbose,
  }) {
    return RefractorSettings(
      artifactJson: artifactJson ?? this.artifactJson,
      exclude: exclude ?? this.exclude,
      verbose: verbose ?? this.verbose,
    );
  }
}
