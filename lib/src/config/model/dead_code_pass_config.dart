part of 'pass_config.dart';

@JsonSerializable(
  checked: true,
  fieldRename: FieldRename.snake,
  createToJson: false,
)
final class DeadCodePassConfig extends PassConfig {
  DeadCodePassConfig({
    super.enabled,
    this.maxInsertionsPerProcedure = 2,
  });

  factory DeadCodePassConfig.fromJson(Map<String, dynamic> json) =>
      _$DeadCodePassConfigFromJson(json);

  final int maxInsertionsPerProcedure;
}
