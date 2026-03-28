import 'package:refractor/src/engine/pass/config/pass_config.dart';

final class StringEncryptPassConfig extends PassConfig {
  const StringEncryptPassConfig({
    super.enabled,
    super.exclude,
    this.xorKey = 0x5A,
    this.excludePatterns = const [],
  });

  factory StringEncryptPassConfig.fromJson(Map<String, dynamic> json) {
    return StringEncryptPassConfig(
      enabled: json['enabled'] as bool? ?? true,
      exclude: (json['exclude'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      xorKey: json['xor_key'] as int? ?? 0x5A,
      excludePatterns: (json['exclude_patterns'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
    );
  }

  final int xorKey;
  final List<String> excludePatterns;
}
