import 'package:json_annotation/json_annotation.dart';
import 'package:refractor/src/config/model/pass_config.dart';
import 'package:refractor/src/exceptions/refractor_exception.dart';

class PassConfigListConverter
    implements JsonConverter<List<PassConfig>, Map<String, dynamic>> {
  const PassConfigListConverter();

  @override
  List<PassConfig> fromJson(Map<String, dynamic> json) {
    return json.entries.map((entry) {
      final type = entry.key;
      final value = entry.value;

      // `true` means enabled with defaults, `false` means disabled.
      final map = switch (value) {
        true => <String, dynamic>{},
        false => <String, dynamic>{'enabled': false},
        Map() => Map<String, dynamic>.from(value),
        _ => throw ConfigException('Invalid config for pass "$type": $value'),
      };

      return _parseBuiltInPassConfig(type, map);
    }).toList();
  }

  PassConfig _parseBuiltInPassConfig(String name, Map<String, dynamic> json) =>
      switch (name) {
        'rename' => RenamePassConfig.fromJson(json),
        'string_encrypt' => StringEncryptPassConfig.fromJson(json),
        _ => throw ConfigException('Unknown pass type: $name'),
      };

  @override
  Map<String, dynamic> toJson(List<PassConfig> object) =>
      throw UnimplementedError();
}
