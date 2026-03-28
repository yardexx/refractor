import 'package:kernel/kernel.dart';
import 'package:refractor/src/config/model/refractor_config.dart';
import 'package:refractor/src/engine/pass/pass_registry.dart';
import 'package:refractor/src/policy/policy_resolver.dart';
import 'package:refractor/src/project/project_scope.dart';
import 'package:test/test.dart';

void main() {
  group('RefractorConfig.fromYaml', () {
    test('throws ConfigException for empty YAML', () {
      expect(
        () => RefractorConfig.fromYaml(''),
        throwsA(isA<Exception>()),
      );
    });

    test('throws ConfigException for malformed YAML', () {
      expect(
        () => RefractorConfig.fromYaml('refractor: [passes: [rename: true'),
        throwsA(isA<Exception>()),
      );
    });

    test('throws ConfigException for non-map YAML root', () {
      expect(
        () => RefractorConfig.fromYaml('- rename\n- string_encrypt'),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects legacy top-level passes', () {
      expect(
        () => RefractorConfig.fromYaml('''
passes:
  rename: true
'''),
        throwsA(
          predicate(
            (e) => e.toString().contains('refractor.passes'),
          ),
        ),
      );
    });

    test('rejects legacy top-level exclude', () {
      expect(
        () => RefractorConfig.fromYaml('''
exclude:
  - "**/*.g.dart"
'''),
        throwsA(
          predicate(
            (e) => e.toString().contains('refractor.exclude'),
          ),
        ),
      );
    });

    test('parses boolean pass toggles under refractor.passes', () {
      final config = RefractorConfig.fromYaml('''
refractor:
  passes:
    rename: false
    string_encrypt: true
''');

      expect(
        config.passes.whereType<RenamePassConfig>().single.enabled,
        isFalse,
      );
      expect(
        config.passes.whereType<StringEncryptPassConfig>().single.enabled,
        isTrue,
      );
    });

    test('parses global excludes under refractor.exclude', () {
      final config = RefractorConfig.fromYaml('''
refractor:
  exclude:
    - "**/*.g.dart"
  passes:
    rename: true
''');

      expect(config.excludePatterns, hasLength(1));
      expect(
        config.excludePatterns.single.matches('lib/src/user.g.dart'),
        isTrue,
      );
    });

    test('throws ConfigException for unknown pass', () {
      expect(
        () => RefractorConfig.fromYaml('''
refractor:
  passes:
    unknown_pass: true
'''),
        throwsA(
          predicate(
            (e) => e.toString().contains('Unknown pass type: unknown_pass'),
          ),
        ),
      );
    });
  });

  group('PassRegistry', () {
    test('builds only enabled passes with concrete options', () {
      final config = RefractorConfig.fromYaml('''
refractor:
  passes:
    rename: false
    string_encrypt:
      xor_key: 23
''');
      final projectScope = ProjectScope(
        projectRootUri: Uri.directory('/virtual/project'),
        projectPackageName: 'refractor',
      );
      final policy = PolicyResolver().resolve(
        component: _emptyComponent(),
        config: config,
        projectScope: projectScope,
      );

      final passes = defaultPassRegistry.createAll(
        configs: config.passes,
        policy: policy,
        projectScope: projectScope,
      );

      expect(passes.length, 1);
      expect(passes[0].name, 'string_encrypt');
    });

    test('preserves YAML pass order', () {
      final config = RefractorConfig.fromYaml('''
refractor:
  passes:
    string_encrypt: true
    rename: true
''');
      final projectScope = ProjectScope(
        projectRootUri: Uri.directory('/virtual/project'),
        projectPackageName: 'refractor',
      );
      final policy = PolicyResolver().resolve(
        component: _emptyComponent(),
        config: config,
        projectScope: projectScope,
      );

      final passes = defaultPassRegistry.createAll(
        configs: config.passes,
        policy: policy,
        projectScope: projectScope,
      );

      expect(passes.map((pass) => pass.name).toList(), [
        'string_encrypt',
        'rename',
      ]);
    });
  });

  group('RefractorConfig.excludePatterns', () {
    test('maps exclude settings to Glob list', () {
      final config = RefractorConfig(
        refractor: const RefractorSettings(
          exclude: ['**/*.g.dart'],
        ),
      );

      final patterns = config.excludePatterns;
      expect(patterns, hasLength(1));
      expect(
        patterns.single.matches('lib/src/user.g.dart'),
        isTrue,
      );
    });
  });
}

Component _emptyComponent() {
  return Component()..setMainMethodAndMode(null, true);
}
