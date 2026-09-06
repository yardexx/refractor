import 'package:refractor/src/engine/pass/config/pass_config.dart';

final class StringEncryptPassConfig extends PassConfig {
  const StringEncryptPassConfig({
    super.enabled,
    super.exclude,
    this.seed = 0x5A,
    this.excludePatterns = const [],
  });

  factory StringEncryptPassConfig.fromJson(Map<String, dynamic> json) {
    return StringEncryptPassConfig(
      enabled: json['enabled'] as bool? ?? true,
      exclude: (json['exclude'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      seed: json['seed'] as int? ?? 0x5A,
      excludePatterns: (json['exclude_patterns'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
    );
  }

  final int seed;
  final List<String> excludePatterns;
}
