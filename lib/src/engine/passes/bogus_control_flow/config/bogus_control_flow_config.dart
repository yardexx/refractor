import 'package:refractor/src/engine/pass/config/pass_config.dart';

final class BogusControlFlowPassConfig extends PassConfig {
  const BogusControlFlowPassConfig({
    super.enabled,
    super.exclude,
    this.seed = 0x3D,
    this.maxStatements = 16,
  });

  factory BogusControlFlowPassConfig.fromJson(Map<String, dynamic> json) {
    return BogusControlFlowPassConfig(
      enabled: json['enabled'] as bool? ?? true,
      exclude: (json['exclude'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      seed: json['seed'] as int? ?? 0x3D,
      maxStatements: json['max_statements'] as int? ?? 16,
    );
  }

  /// Seeds the guard-parameter choice; a given seed yields the same plan.
  final int seed;

  /// Only functions whose body has at most this many top-level statements are
  /// wrapped. The body is cloned into the bogus branch, so this bounds the
  /// code-size cost.
  final int maxStatements;
}
