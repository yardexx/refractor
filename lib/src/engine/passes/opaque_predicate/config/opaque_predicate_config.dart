import 'package:refractor/src/engine/pass/config/pass_config.dart';

final class OpaquePredicatePassConfig extends PassConfig {
  const OpaquePredicatePassConfig({
    super.enabled,
    super.exclude,
    this.seed = _defaultSeed,
  });

  factory OpaquePredicatePassConfig.fromJson(Map<String, dynamic> json) {
    return OpaquePredicatePassConfig(
      enabled: json['enabled'] as bool? ?? true,
      exclude: (json['exclude'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      seed: json['seed'] as int? ?? _defaultSeed,
    );
  }

  static const int _defaultSeed = 0x05A1;

  /// Seeds the per-site template and constant choices, so output is
  /// deterministic for a given seed.
  final int seed;
}
