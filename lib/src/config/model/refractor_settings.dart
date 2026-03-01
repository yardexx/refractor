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
    this.packageFilter,
    this.verbose = false,
    this.includePackages = const [],
    this.excludePackages = const [],
  });

  factory RefractorSettings.fromJson(Map<String, dynamic> json) =>
      _$RefractorSettingsFromJson(json);

  final String symbolMap;
  final List<String> exclude;
  final String? packageFilter;
  final bool verbose;
  final List<String> includePackages;
  final List<String> excludePackages;

  RefractorSettings copyWith({
    String? symbolMap,
    List<String>? exclude,
    String? packageFilter,
    bool? verbose,
    List<String>? includePackages,
    List<String>? excludePackages,
  }) {
    return RefractorSettings(
      symbolMap: symbolMap ?? this.symbolMap,
      exclude: exclude ?? this.exclude,
      packageFilter: packageFilter ?? this.packageFilter,
      verbose: verbose ?? this.verbose,
      includePackages: includePackages ?? this.includePackages,
      excludePackages: excludePackages ?? this.excludePackages,
    );
  }
}
