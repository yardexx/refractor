// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pass_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeadCodePassConfig _$DeadCodePassConfigFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'DeadCodePassConfig',
      json,
      ($checkedConvert) {
        final val = DeadCodePassConfig(
          enabled: $checkedConvert('enabled', (v) => v as bool? ?? true),
          maxInsertionsPerProcedure: $checkedConvert(
            'max_insertions_per_procedure',
            (v) => (v as num?)?.toInt() ?? 2,
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'maxInsertionsPerProcedure': 'max_insertions_per_procedure',
      },
    );

RenamePassConfig _$RenamePassConfigFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'RenamePassConfig',
  json,
  ($checkedConvert) {
    final val = RenamePassConfig(
      enabled: $checkedConvert('enabled', (v) => v as bool? ?? true),
      preserveMain: $checkedConvert('preserve_main', (v) => v as bool? ?? true),
      excludeNames: $checkedConvert(
        'exclude_names',
        (v) =>
            (v as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      ),
      excludePatterns: $checkedConvert(
        'exclude_patterns',
        (v) =>
            (v as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      ),
      excludeAnnotations: $checkedConvert(
        'exclude_annotations',
        (v) =>
            (v as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'preserveMain': 'preserve_main',
    'excludeNames': 'exclude_names',
    'excludePatterns': 'exclude_patterns',
    'excludeAnnotations': 'exclude_annotations',
  },
);

StringEncryptPassConfig _$StringEncryptPassConfigFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'StringEncryptPassConfig',
  json,
  ($checkedConvert) {
    final val = StringEncryptPassConfig(
      enabled: $checkedConvert('enabled', (v) => v as bool? ?? true),
      xorKey: $checkedConvert('xor_key', (v) => (v as num?)?.toInt() ?? 0x5A),
      excludePatterns: $checkedConvert(
        'exclude_patterns',
        (v) =>
            (v as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'xorKey': 'xor_key',
    'excludePatterns': 'exclude_patterns',
  },
);
