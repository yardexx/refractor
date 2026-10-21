import 'package:refractor/src/engine/pass/config/pass_config.dart';

/// Configuration for the virtualization pass. Opt-in (disabled by default);
/// only functions annotated `@Refractor.virtualize()` are affected.
final class VirtualizePassConfig extends PassConfig {
  const VirtualizePassConfig({
    super.enabled = false,
    super.exclude,
    this.seed = 0,
    this.maxOps = 4096,
  });

  factory VirtualizePassConfig.fromJson(Map<String, dynamic> json) {
    return VirtualizePassConfig(
      enabled: json['enabled'] as bool? ?? false,
      exclude: (json['exclude'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      seed: json['seed'] as int? ?? 0,
      maxOps: json['max_ops'] as int? ?? 4096,
    );
  }

  /// Build seed for ISA/encoding diversity (M1). 0 => random per build.
  final int seed;

  /// Skip functions whose lowered program exceeds this instruction count.
  final int maxOps;
}
