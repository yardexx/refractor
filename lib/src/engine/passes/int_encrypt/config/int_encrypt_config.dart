import 'package:refractor/src/engine/pass/config/pass_config.dart';

final class IntEncryptPassConfig extends PassConfig {
  const IntEncryptPassConfig({
    super.enabled,
    super.exclude,
    this.seed = 0x1F,
    this.minMagnitude = 2,
  });

  factory IntEncryptPassConfig.fromJson(Map<String, dynamic> json) {
    return IntEncryptPassConfig(
      enabled: json['enabled'] as bool? ?? true,
      exclude: (json['exclude'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      seed: json['seed'] as int? ?? 0x1F,
      minMagnitude: json['min_magnitude'] as int? ?? 2,
    );
  }

  /// Seeds the per-literal key PRNG; a given seed yields the same plan.
  final int seed;

  /// Literals whose absolute value is below this are left alone. Keeps the
  /// ubiquitous trivial constants (-1, 0, 1 at the default of 2) inline so the
  /// pass does not turn every loop counter and index into a call.
  final int minMagnitude;
}
