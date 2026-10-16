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
    $checkKeys(
      json,
      allowedKeys: const ['artifact_json', 'symbol_map', 'exclude', 'verbose'],
    );
    final val = RefractorSettings(
      artifactJson: $checkedConvert(
        'artifact_json',
        (v) => v as String? ?? 'build_artifacts.json',
      ),
      symbolMap: $checkedConvert(
        'symbol_map',
        (v) => v as String? ?? 'symbol_map.json',
      ),
      exclude: $checkedConvert(
        'exclude',
        (v) =>
            (v as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      ),
      verbose: $checkedConvert('verbose', (v) => v as bool? ?? false),
    );
    return val;
  },
  fieldKeyMap: const {
    'artifactJson': 'artifact_json',
    'symbolMap': 'symbol_map',
  },
);
