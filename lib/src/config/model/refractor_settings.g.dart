// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'refractor_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RefractorSettings _$RefractorSettingsFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'RefractorSettings',
  json,
  ($checkedConvert) {
    final val = RefractorSettings(
      symbolMap: $checkedConvert(
        'symbol_map',
        (v) => v as String? ?? 'symbol_map.json',
      ),
      exclude: $checkedConvert(
        'exclude',
        (v) =>
            (v as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      ),
      packageFilter: $checkedConvert('package_filter', (v) => v as String?),
      verbose: $checkedConvert('verbose', (v) => v as bool? ?? false),
      includePackages: $checkedConvert(
        'include_packages',
        (v) =>
            (v as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      ),
      excludePackages: $checkedConvert(
        'exclude_packages',
        (v) =>
            (v as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'symbolMap': 'symbol_map',
    'packageFilter': 'package_filter',
    'includePackages': 'include_packages',
    'excludePackages': 'exclude_packages',
  },
);
