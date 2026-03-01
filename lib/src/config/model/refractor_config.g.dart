// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'refractor_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RefractorConfig _$RefractorConfigFromJson(Map<String, dynamic> json) =>
    $checkedCreate('RefractorConfig', json, ($checkedConvert) {
      final val = RefractorConfig(
        refractor: $checkedConvert(
          'refractor',
          (v) => v == null
              ? const RefractorSettings()
              : RefractorSettings.fromJson(v as Map<String, dynamic>),
        ),
        passes: $checkedConvert(
          'passes',
          (v) => v == null
              ? const []
              : const PassConfigListConverter().fromJson(
                  v as Map<String, dynamic>,
                ),
        ),
      );
      return val;
    });
