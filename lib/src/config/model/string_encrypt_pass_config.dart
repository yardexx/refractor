part of 'pass_config.dart';

@JsonSerializable(
  checked: true,
  fieldRename: FieldRename.snake,
  createToJson: false,
)
final class StringEncryptPassConfig extends PassConfig {
  StringEncryptPassConfig({
    super.enabled,
    this.xorKey = 0x5A,
    this.excludePatterns = const [],
  });

  factory StringEncryptPassConfig.fromJson(Map<String, dynamic> json) =>
      _$StringEncryptPassConfigFromJson(json);

  final int xorKey;
  final List<String> excludePatterns;
}
