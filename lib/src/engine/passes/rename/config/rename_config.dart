import 'package:refractor/src/engine/pass/config/pass_config.dart';

final class RenamePassConfig extends PassConfig {
  const RenamePassConfig({
    super.enabled,
    super.exclude,
    this.seed,
    this.overloading = false,
  });

  factory RenamePassConfig.fromJson(Map<String, dynamic> json) {
    return RenamePassConfig(
      enabled: json['enabled'] as bool? ?? true,
      exclude: (json['exclude'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      seed: json['seed'] as int?,
      overloading: json['overloading'] as bool? ?? false,
    );
  }

  final int? seed;
  final bool overloading;
}
