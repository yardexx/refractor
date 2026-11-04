import 'package:refractor/refractor.dart';
import 'package:yaml/yaml.dart';

/// The data-driven contract for a fixture, parsed from `expectations.yaml`.
///
/// This is a superset of the original resistance-only schema: the
/// `denylist` / `allowlist` / `rename_helpers` / `required_metrics` keys are
/// unchanged, so existing fixtures keep working, and three new sections drive
/// the correctness and impact bands.
class Expectations {
  const Expectations({
    this.targets = const [Target.exe],
    this.checkEquivalence = true,
    this.verifyKernel = true,
    this.denylist = const [],
    this.allowlist = const [],
    this.renameHelpers = const [],
    this.requiredMetrics = const {},
    this.maxSizeRatio,
  });

  factory Expectations.fromYaml(String yamlString) {
    final root = loadYaml(yamlString);
    if (root is! YamlMap) {
      throw const FormatException('expectations.yaml root must be a mapping.');
    }
    final map = _plainMap(root);

    final behavior = _mapAt(map, 'behavior');
    final resistance = _mapAt(map, 'resistance');
    final impact = _mapAt(map, 'impact');

    // Resistance keys are also accepted at the root for backward
    // compatibility with the pre-prism fixtures.
    List<String> resist(String key) => _stringList(resistance[key] ?? map[key]);

    return Expectations(
      targets: _targets(behavior['targets'] ?? map['targets']),
      checkEquivalence: _bool(behavior['equivalent_to_plain'], true),
      verifyKernel: _bool(behavior['verify_kernel'], true),
      denylist: resist('denylist'),
      allowlist: resist('allowlist'),
      renameHelpers: resist('rename_helpers'),
      requiredMetrics: _metrics(
        resistance['required_metrics'] ?? map['required_metrics'],
      ),
      maxSizeRatio: _double(impact['max_size_ratio']),
    );
  }

  /// Compilation targets the correctness band should exercise.
  final List<Target> targets;

  /// Whether the obfuscated binary must produce the same stdout as a plain
  /// (non-obfuscated) build of the same source.
  final bool checkEquivalence;

  /// Whether the obfuscated kernel must pass the kernel verifier.
  final bool verifyKernel;

  final List<String> denylist;
  final List<String> allowlist;
  final List<String> renameHelpers;
  final Map<String, int> requiredMetrics;

  /// Upper bound on obfuscated-binary size as a ratio of the plain build.
  /// `null` disables the assertion (the ratio is still reported).
  final double? maxSizeRatio;

  static Map<String, Object?> _mapAt(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value == null) return const {};
    if (value is! Map) {
      throw FormatException('"$key" must be a mapping.');
    }
    return value.cast<String, Object?>();
  }

  static List<Target> _targets(Object? raw) {
    if (raw == null) return const [Target.exe];
    if (raw is! List) {
      throw const FormatException('"targets" must be a list.');
    }
    return raw
        .map((e) => Target.fromString(e.toString()))
        .toList(growable: false);
  }

  static Map<String, int> _metrics(Object? raw) {
    if (raw == null) return const {};
    if (raw is! Map) {
      throw const FormatException('"required_metrics" must be a mapping.');
    }
    return {
      for (final entry in raw.entries)
        entry.key.toString(): entry.value is int
            ? entry.value as int
            : throw FormatException(
                'Metric "${entry.key}" must be an integer.',
              ),
    };
  }

  static bool _bool(Object? raw, bool fallback) => raw is bool ? raw : fallback;

  static double? _double(Object? raw) => switch (raw) {
    null => null,
    final num n => n.toDouble(),
    _ => throw FormatException('Expected a number, got "$raw".'),
  };

  static List<String> _stringList(Object? raw) {
    if (raw == null) return const [];
    if (raw is! List) {
      throw const FormatException('Expected a list of strings.');
    }
    return raw.map((e) => e.toString()).toList(growable: false);
  }

  static Map<String, Object?> _plainMap(YamlMap yaml) => {
    for (final entry in yaml.entries) entry.key.toString(): _plain(entry.value),
  };

  static Object? _plain(Object? node) => switch (node) {
    final YamlMap m => _plainMap(m),
    final YamlList l => l.map(_plain).toList(),
    _ => node,
  };
}
