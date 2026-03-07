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
  });

  group('RefractorConfig.toOptions', () {
    test('maps rename and global settings correctly', () {
      final config = RefractorConfig(
        refractor: const RefractorSettings(
          exclude: ['**/*.g.dart'],
          verbose: true,
        ),
        passes: [
          RenamePassConfig(preserveMain: false),
        ],
      );

      final options = config.toOptions();

      expect(options.preserveMain, isFalse);
      expect(options.verbose, isTrue);
      expect(
        options.excludeLibraryUriPatterns.single.matches(
          'package:my_app/src/user.g.dart',
        ),
        isTrue,
      );
    });

    test('maps string encryption exclude patterns to regex list', () {
      final config = RefractorConfig.fromYaml('''
passes:
  string_encrypt:
    exclude_patterns:
      - "^https://"
      - "SECRET"
''');

      final options = config.toOptions();

      expect(options.stringExcludePatterns, hasLength(2));
      expect(
        options.stringExcludePatterns[0].hasMatch('https://api.test'),
        isTrue,
      );
      expect(options.stringExcludePatterns[1].hasMatch('SECRET_KEY'), isTrue);
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
