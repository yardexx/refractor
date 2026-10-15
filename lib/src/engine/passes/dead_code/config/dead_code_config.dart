import 'package:refractor/src/engine/pass/config/pass_config.dart';

final class DeadCodePassConfig extends PassConfig {
  const DeadCodePassConfig({
    super.enabled,
    super.exclude,
    this.seed = _defaultSeed,
  });

  factory DeadCodePassConfig.fromJson(Map<String, dynamic> json) {
    return DeadCodePassConfig(
      enabled: json['enabled'] as bool? ?? true,
      exclude: (json['exclude'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      seed: json['seed'] as int? ?? _defaultSeed,
    );
  }

  static const int _defaultSeed = 0x0DEAD;

  /// Seeds the junk-constant choices, so output is deterministic for a given
  /// seed.
  final int seed;
}
