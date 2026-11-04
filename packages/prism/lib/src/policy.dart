import 'dart:io';

import 'package:yaml/yaml.dart';

/// Whether a failed assertion fails the run or is only advisory.
enum PolicySeverity { error, warn }

/// A single customer-authored assertion about the built artifact.
///
/// These express the customer's *own* requirements — secrets, internal
/// hostnames, markers that must or must not survive — which the symbol map
/// cannot know. They are independent of the map band and can run with no map
/// at all.
sealed class Assertion {
  const Assertion(this.severity);

  final PolicySeverity severity;

  String get label;
}

/// Literal strings that must not appear anywhere in the artifact.
class MustNotContain extends Assertion {
  const MustNotContain(this.needles, PolicySeverity severity) : super(severity);

  final List<String> needles;

  @override
  String get label => 'must_not_contain';
}

/// Literal strings that must appear in the artifact (e.g. a kept marker).
class MustContain extends Assertion {
  const MustContain(this.needles, PolicySeverity severity) : super(severity);

  final List<String> needles;

  @override
  String get label => 'must_contain';
}

/// A regular expression that must not match anywhere in the artifact.
class MustNotMatch extends Assertion {
  const MustNotMatch(
    this.pattern, {
    required PolicySeverity severity,
    this.caseInsensitive = false,
  }) : super(severity);

  final String pattern;
  final bool caseInsensitive;

  RegExp get regExp => RegExp(pattern, caseSensitive: !caseInsensitive);

  @override
  String get label => 'must_not_match';
}

/// A parsed `prism.policy.yaml`.
class Policy {
  const Policy(this.assertions);

  factory Policy.parse(String yamlString) {
    final root = loadYaml(yamlString);
    if (root is! YamlMap) {
      throw const FormatException('policy root must be a mapping.');
    }
    final rawAssertions = root['assertions'];
    if (rawAssertions is! YamlList) {
      throw const FormatException('policy must have an "assertions" list.');
    }
    return Policy([
      for (final entry in rawAssertions) _parseAssertion(entry),
    ]);
  }

  factory Policy.load(String path) =>
      Policy.parse(File(path).readAsStringSync());

  final List<Assertion> assertions;

  static Assertion _parseAssertion(Object? node) {
    if (node is! YamlMap) {
      throw const FormatException('each assertion must be a mapping.');
    }
    final severity = _severity(node['severity']);

    if (node.containsKey('must_not_contain')) {
      return MustNotContain(_stringList(node['must_not_contain']), severity);
    }
    if (node.containsKey('must_contain')) {
      return MustContain(_stringList(node['must_contain']), severity);
    }
    if (node.containsKey('must_not_match')) {
      final pattern = node['must_not_match'];
      if (pattern is! String) {
        throw const FormatException('must_not_match must be a string regex.');
      }
      return MustNotMatch(
        pattern,
        severity: severity,
        caseInsensitive: node['case_insensitive'] == true,
      );
    }
    throw FormatException(
      'unknown assertion; expected one of must_not_contain, must_contain, '
      'must_not_match. Got keys: ${node.keys.join(', ')}',
    );
  }

  static PolicySeverity _severity(Object? raw) => switch (raw) {
        null || 'error' => PolicySeverity.error,
        'warn' => PolicySeverity.warn,
        _ => throw FormatException(
            'severity must be "error" or "warn", got "$raw"',
          ),
      };

  static List<String> _stringList(Object? raw) {
    if (raw is String) return [raw];
    if (raw is YamlList) return raw.map((e) => e.toString()).toList();
    throw const FormatException('expected a string or list of strings.');
  }
}
