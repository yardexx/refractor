// obfuscator_test.dart
// Purpose: Stress-test a Dart obfuscator with diverse language features.

import 'dart:async';
import 'dart:math';

void main(List<String> args) async {
  Logger.global.logLevel = LogLevel.debug;

  final app = Application<AppConfig>(
    config: AppConfig(
      appName: 'ObfuscatorTest',
      version: 1,
      flags: {'experimental': true},
    ),
  );

  await app.start();

  final result = computeComplexValue(5);
  Logger.global.debug('Computed value: $result');

  final service = RandomService(seed: 42);
  Logger.global.info('Random value: ${service.next()}');

  try {
    dangerousOperation(-1);
  } catch (e, st) {
    Logger.global.error('Caught error: $e\n$st');
  }

  final transformer = StringTransformer();
  final transformed = transformer.transformAll([
    'alpha',
    'beta',
    'gamma',
  ], (s) => s.toUpperCase());

  Logger.global.info('Transformed: $transformed');

  final lazy = Lazy<int>(() {
    Logger.global.debug('Lazy value evaluated');
    return 99;
  });

  Logger.global.info('Lazy value is ${lazy.value}');
}

/// ------------------------------------------------------------
/// Core application structures
/// ------------------------------------------------------------

class Application<T extends BaseConfig> with Lifecycle {
  final T config;

  Application({required this.config});

  @override
  Future<void> start() async {
    Logger.global.info('Starting ${config.appName} v${config.version}');

    await Future.delayed(const Duration(milliseconds: 100));

    if (config.flags['experimental'] == true) {
      Logger.global.warn('Experimental features enabled');
    }
  }

  @override
  Future<void> stop() async {
    Logger.global.info('Stopping application');
  }
}

abstract class BaseConfig {
  String get appName;
  int get version;
  Map<String, bool> get flags;
}

class AppConfig implements BaseConfig {
  @override
  final String appName;

  @override
  final int version;

  @override
  final Map<String, bool> flags;

  const AppConfig({
    required this.appName,
    required this.version,
    required this.flags,
  });
}

/// ------------------------------------------------------------
/// Logging system
/// ------------------------------------------------------------

enum LogLevel { debug, info, warn, error }

class Logger {
  static final Logger global = Logger._internal();

  LogLevel logLevel = LogLevel.info;

  Logger._internal();

  void debug(String message) {
    _log(LogLevel.debug, message);
  }

  void info(String message) {
    _log(LogLevel.info, message);
  }

  void warn(String message) {
    _log(LogLevel.warn, message);
  }

  void error(String message) {
    _log(LogLevel.error, message);
  }

  void _log(LogLevel level, String message) {
    if (level.index < logLevel.index) return;

    final timestamp = DateTime.now().toIso8601String();
    print('[$timestamp][$level] $message');
  }
}

/// ------------------------------------------------------------
/// Mixins & utilities
/// ------------------------------------------------------------

mixin Lifecycle {
  Future<void> start();
  Future<void> stop();
}

class RandomService {
  final Random _random;

  RandomService({int? seed}) : _random = Random(seed);

  int next() => _random.nextInt(100);
}

class Lazy<T> {
  T? _cached;
  final T Function() _factory;

  Lazy(this._factory);

  T get value => _cached ??= _factory();
}

/// ------------------------------------------------------------
/// Algorithms & transformations
/// ------------------------------------------------------------

int computeComplexValue(int n) {
  if (n <= 0) return 0;
  return n * n + computeComplexValue(n - 1);
}

void dangerousOperation(int value) {
  if (value < 0) {
    throw ArgumentError.value(value, 'value', 'Must be >= 0');
  }
}

class StringTransformer {
  List<String> transformAll(
    Iterable<String> input,
    String Function(String) transformer,
  ) {
    return input.map(transformer).toList(growable: false);
  }
}

/// ------------------------------------------------------------
/// Dead / unused code (should still be obfuscated)
/// ------------------------------------------------------------

// ignore: unused_element
class _UnusedClass {
  final String secret;

  _UnusedClass(this.secret);

  String reveal() => 'Secret: $secret';
}

// ignore: unused_element
int _unusedFunction(int x) {
  return x ^ 0xDEADBEEF;
}

// ignore: unused_element
const Map<String, dynamic> _unusedConstants = {
  'pi': 3.14159,
  'answer': 42,
  'nested': {'key': 'value'},
};
