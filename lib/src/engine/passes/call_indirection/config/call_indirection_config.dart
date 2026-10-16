import 'package:refractor/src/engine/pass/config/pass_config.dart';

final class CallIndirectionPassConfig extends PassConfig {
  const CallIndirectionPassConfig({
    super.enabled,
    super.exclude,
  });

  factory CallIndirectionPassConfig.fromJson(Map<String, dynamic> json) {
    return CallIndirectionPassConfig(
      enabled: json['enabled'] as bool? ?? true,
      exclude: (json['exclude'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
    );
  }
}
