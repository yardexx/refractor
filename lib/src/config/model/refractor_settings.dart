import 'package:json_annotation/json_annotation.dart';

part 'refractor_settings.g.dart';

@JsonSerializable(
  checked: true,
  fieldRename: FieldRename.snake,
  createToJson: false,
)
final class RefractorSettings {
  const RefractorSettings({
    this.symbolMap = 'symbol_map.json',
    this.exclude = const [],
    this.verbose = false,
  });

  factory RefractorSettings.fromJson(Map<String, dynamic> json) =>
      _$RefractorSettingsFromJson(json);

  final String symbolMap;
  final List<String> exclude;
  final bool verbose;

  RefractorSettings copyWith({
    String? symbolMap,
    List<String>? exclude,
    bool? verbose,
  }) {
    return RefractorSettings(
      symbolMap: symbolMap ?? this.symbolMap,
      exclude: exclude ?? this.exclude,
      verbose: verbose ?? this.verbose,
    );
  }
}
