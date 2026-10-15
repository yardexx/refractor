import 'package:refractor/src/engine/pass/config/pass_config.dart';

final class ControlFlowFlattenPassConfig extends PassConfig {
  const ControlFlowFlattenPassConfig({
    super.enabled,
    super.exclude,
    this.seed = _defaultSeed,
  });

  factory ControlFlowFlattenPassConfig.fromJson(Map<String, dynamic> json) {
    return ControlFlowFlattenPassConfig(
      enabled: json['enabled'] as bool? ?? true,
      exclude: (json['exclude'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      seed: json['seed'] as int? ?? _defaultSeed,
    );
  }

  static const int _defaultSeed = 0x0CFF;

  /// Seeds the case-layout shuffle, so output is deterministic for a given
  /// seed.
  final int seed;
}
