import 'package:refractor/src/config/model/refractor_config.dart';
import 'package:refractor/src/engine/passes/rename/rename_pass.dart';
import 'package:refractor/src/engine/passes/string_encrypt/string_encrypt_pass.dart';
import 'package:refractor/src/exceptions/refractor_exception.dart';
import 'package:test/test.dart';

void main() {
  group('RefractorConfig.fromYaml', () {
    test('throws ConfigException for empty YAML', () {
      expect(
        () => RefractorConfig.fromYaml(''),
        throwsA(isA<ConfigException>()),
      );
    });

    test('throws ConfigException for malformed YAML', () {
      expect(
        () => RefractorConfig.fromYaml('passes: [rename: true'),
        throwsA(isA<ConfigException>()),
      );
    });

    test('throws ConfigException for non-map YAML root', () {
      expect(
        () => RefractorConfig.fromYaml('- rename\n- string_encrypt'),
        throwsA(isA<ConfigException>()),
      );
    });

    test('parses boolean pass toggles', () {
      final config = RefractorConfig.fromYaml('''
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

    test('throws ConfigException for unknown pass', () {
      expect(
        () => RefractorConfig.fromYaml('''
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

  group('RefractorConfig.buildPasses', () {
    test('builds only enabled passes with concrete options', () {
      final config = RefractorConfig.fromYaml('''
passes:
  rename: false
  string_encrypt:
    xor_key: 23
''');

      final passes = config.buildPasses();

      expect(passes.length, 1);
      expect(passes[0], isA<StringEncryptPass>());
      expect((passes[0] as StringEncryptPass).xorKey, 23);
    });

    test('rename pass gets typed options from config', () {
      final config = RefractorConfig.fromYaml('''
passes:
  rename:
    preserve_main: false
    seed: 42
''');

      final passes = config.buildPasses();

      expect(passes.length, 1);
      expect(passes[0], isA<RenamePass>());
      final renamePass = passes[0] as RenamePass;
      expect(renamePass.options.preserveMain, isFalse);
      expect(renamePass.options.seed, 42);
    });

    test('string encrypt pass gets exclude patterns from config', () {
      final config = RefractorConfig.fromYaml('''
passes:
  string_encrypt:
    exclude_patterns:
      - "^https://"
      - "SECRET"
''');

      final passes = config.buildPasses();

      expect(passes.length, 1);
      final stringPass = passes[0] as StringEncryptPass;
      expect(stringPass.excludePatterns, hasLength(2));
      expect(stringPass.excludePatterns[0].hasMatch('https://api.test'), isTrue);
      expect(stringPass.excludePatterns[1].hasMatch('SECRET_KEY'), isTrue);
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
        patterns.single.matches('package:my_app/src/user.g.dart'),
        isTrue,
      );
    });
  });

  group('RefractorConfig.passesFromNames', () {
    test('creates passes from valid names', () {
      final passes = RefractorConfig.passesFromNames([
        'rename',
        'string_encrypt',
      ]);

      expect(passes[0], isA<RenamePass>());
      expect(passes[1], isA<StringEncryptPass>());
    });

    test('throws ConfigException for invalid names', () {
      expect(
        () => RefractorConfig.passesFromNames(['rename', 'bad']),
        throwsA(isA<ConfigException>()),
      );
    });
  });
}
