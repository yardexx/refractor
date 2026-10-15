import 'package:refractor/src/engine/pass/config/pass_config.dart';

final class ArithmeticManglePassConfig extends PassConfig {
  const ArithmeticManglePassConfig({
    super.enabled,
    super.exclude,
    this.seed = _defaultSeed,
  });

  factory ArithmeticManglePassConfig.fromJson(Map<String, dynamic> json) {
    return ArithmeticManglePassConfig(
      enabled: json['enabled'] as bool? ?? true,
      exclude: (json['exclude'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      seed: json['seed'] as int? ?? _defaultSeed,
    );
  }

  static const int _defaultSeed = 0x0A17;

  /// Seeds the per-site constant choices, so output is deterministic for a
  /// given seed.
  final int seed;
}
