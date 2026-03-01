import 'dart:io';

import 'package:refractor/src/config/config_manager.dart';
import 'package:refractor/src/config/model/refractor_config.dart';
import 'package:refractor/src/exceptions/refractor_exception.dart';
import 'package:test/test.dart';

void main() {
  group('ConfigManager.loadConfig', () {
    late Directory tempDir;
    late String originalCurrentDir;

    setUp(() async {
      originalCurrentDir = Directory.current.path;
      tempDir = await Directory.systemTemp.createTemp('refractor_config_test_');
      Directory.current = tempDir.path;
    });

    tearDown(() async {
      Directory.current = originalCurrentDir;
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('throws when no config file is present', () {
      File('pubspec.yaml').writeAsStringSync('name: sample_app\n');

      expect(
        ConfigManager.loadConfig,
        throwsA(isA<ConfigException>()),
      );
    });

    test('loads valid config file', () {
      File('pubspec.yaml').writeAsStringSync('name: sample_app\n');
      File('refractor.yaml').writeAsStringSync('''
passes:
  rename: true
''');

      final config = ConfigManager.loadConfig();

      expect(
        config.passes.whereType<RenamePassConfig>().single.enabled,
        isTrue,
      );
    });

    test('loads config even when pubspec.yaml is missing', () {
      File('refractor.yaml').writeAsStringSync('''
passes:
  rename: true
''');

      final config = ConfigManager.loadConfig();

      expect(
        config.passes.whereType<RenamePassConfig>().single.enabled,
        isTrue,
      );
    });

    test('loads explicit configPath when provided', () {
      File('pubspec.yaml').writeAsStringSync('name: sample_app\n');
      File('custom.yaml').writeAsStringSync('''
passes:
  rename: false
  string_encrypt: true
''');

      final config = ConfigManager.loadConfig(configPath: 'custom.yaml');

      expect(
        config.passes.whereType<RenamePassConfig>().single.enabled,
        isFalse,
      );
      expect(
        config.passes.whereType<StringEncryptPassConfig>().single.enabled,
        isTrue,
      );
    });

    test('throws when specified configPath does not exist', () {
      File('pubspec.yaml').writeAsStringSync('name: sample_app\n');

      expect(
        () => ConfigManager.loadConfig(configPath: 'missing.yaml'),
        throwsA(isA<ConfigException>()),
      );
    });

    test('throws when config file is empty', () {
      File('pubspec.yaml').writeAsStringSync('name: sample_app\n');
      File('refractor.yaml').writeAsStringSync('   \n');

      expect(
        ConfigManager.loadConfig,
        throwsA(isA<ConfigException>()),
      );
    });
  });
}
