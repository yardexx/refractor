part of 'pass_config.dart';

@JsonSerializable(
  checked: true,
  fieldRename: FieldRename.snake,
  createToJson: false,
)
final class RenamePassConfig extends PassConfig {
  RenamePassConfig({
    super.enabled,
    this.preserveMain = true,
    this.excludeNames = const [],
    this.excludePatterns = const [],
    this.excludeAnnotations = const [],
  });

  factory RenamePassConfig.fromJson(Map<String, dynamic> json) =>
      _$RenamePassConfigFromJson(json);

  final bool preserveMain;
  final List<String> excludeNames;
  final List<String> excludePatterns;
  final List<String> excludeAnnotations;
}
