import 'dart:async';

const String exampleVersion = '0.1.0';

void main() async {
  final results = await runExampleApp(verbose: true);
  for (final line in results) {
    print(line);
  }
}

Future<List<String>> runExampleApp({bool verbose = false}) async {
  final app = ExampleApp(
    const AppConfig(
      appName: 'KernelEdgeCases',
      mode: ExampleMode.active,
      enableDiagnostics: true,
    ),
  );

  await app.start();

  final renderer = FancyRenderer(prefix: 'Hello');
  final greeter = GreeterService();
  final holder = MessageHolder();

  final lines = <String>[
    'app=${app.config.appName}@$exampleVersion',
    'mode=${describeMode(app.config.mode)}',
    'override=${greeter.greet(label: 'World', excited: true)}',
    'sdkOverride=${renderer.toString()}',
    'dynamic=${callRenderDynamically(renderer)}',
    'dynamicField=${mutateMessageDynamically(holder)}',
    'construction=${exerciseDirectConstruction()}',
    'tearOffs=${exerciseTearOffs()}',
    'instanceTearOff=${exerciseInstanceTearOff(renderer)}',
    'fieldAliases=${exerciseFieldBackedAliases()}',
    'mutableAlias=${exerciseMutableAlias()}',
    'locals=${exerciseLocalInvocation()}',
    'excluded=${exerciseExcludedMembers()}',
    'secret=${app.secretSummary(renderer)}',
    'enum=${summarizeEnumValues()}',
  ];

  if (verbose) {
    lines.add('interpolation=${buildInterpolatedMessage(renderer)}');
    lines.add('unusedCase=${const _UnusedCase('shadow').reveal()}');
    lines.add('unused=${_unusedFunction(7)}');
  }

  await app.stop();
  return lines;
}

String describeMode(ExampleMode mode) {
  return switch (mode) {
    ExampleMode.idle => 'idle',
    ExampleMode.active => 'active',
    ExampleMode.done => 'done',
  };
}

String summarizeEnumValues() {
  return [for (final mode in ExampleMode.values) mode.name].join(',');
}

@Tag('top-level-named')
String topLevelNamed({required String value, bool debug = false}) {
  return debug ? 'top:$value' : value;
}

String alternateTopLevelNamed({required String value, bool debug = false}) {
  return 'alt:$value';
}

@Tag('generic-helper')
T genericEcho<T>({required T value, bool debug = false}) {
  return value;
}

String callRenderDynamically(dynamic renderer) {
  return renderer.render(label: 'dynamic', excited: true) as String;
}

String mutateMessageDynamically(dynamic holder) {
  holder.message = 'dynamic-message';
  return holder.message as String;
}

String exerciseLocalInvocation() {
  String localFormat({required String input, bool loud = false}) {
    return loud ? input.toUpperCase() : input;
  }

  return localFormat(input: 'local', loud: true);
}

String exerciseDirectConstruction() {
  final payload = Payload.named(value: 'ctor', debug: true);
  final redirected = RedirectPayload<String>.redirect(
    value: 'factory',
    debug: true,
  );
  final redirectedInt = RedirectPayload<int>.redirect(value: 9, debug: true);

  return [
    payload.describe(),
    redirected.describe(),
    redirectedInt.describe(),
  ].join(' | ');
}

String exerciseTearOffs() {
  final topAlias = topLevelNamed;
  final genericAlias = genericEcho<int>;
  final ctorAlias = Payload.named;
  final factoryAlias = RedirectPayload<String>.redirect;
  final instantiatedFactoryAlias = RedirectPayload<int>.redirect;

  final top = topAlias(value: 'alias', debug: true);
  final genericValue = genericAlias(value: 7, debug: true);
  final payload = ctorAlias(value: 'ctor', debug: true);
  final redirected = factoryAlias(value: 'factory', debug: true);
  final redirectedInt = instantiatedFactoryAlias(value: 9, debug: true);

  return [
    top,
    '$genericValue',
    payload.describe(),
    redirected.describe(),
    redirectedInt.describe(),
  ].join(' | ');
}

String exerciseInstanceTearOff(FancyRenderer renderer) {
  final instanceAlias = renderer.render;
  return instanceAlias(label: 'instance', excited: true);
}

String exerciseFieldBackedAliases() {
  final top = AliasHub.finalTopLevelAlias(value: 'field-alias', debug: true);
  final redirected = AliasHub.finalFactoryAlias(
    value: 'field-factory',
    debug: true,
  );
  final instantiated = AliasHub.finalInstantiatedFactoryAlias(
    value: 12,
    debug: true,
  );
  return '$top | ${redirected.describe()} | ${instantiated.describe()}';
}

String exerciseMutableAlias() {
  String Function({required String value, bool debug}) callback = topLevelNamed;
  callback = alternateTopLevelNamed;
  return callback(value: 'mutable', debug: true);
}

String exerciseExcludedMembers() {
  final service = EntryPointService();
  final constructorCase = EntryPointPayload.named(
    value: 'constructor',
    debug: true,
  );
  return [
    service.callback(label: 'entry', excited: true),
    service.createPayload(value: 'payload', debug: true).describe(),
    constructorCase.describe(),
  ].join(' | ');
}

String buildInterpolatedMessage(FancyRenderer renderer) {
  final mode = describeMode(ExampleMode.done);
  return 'interpolated:${renderer.render(label: mode, excited: true)}';
}

class Tag {
  const Tag(this.label);

  final String label;
}

enum ExampleMode { idle, active, done }

mixin Lifecycle {
  Future<void> start();
  Future<void> stop();
}

abstract class NamedService {
  String greet({required String label, bool excited = false});
}

mixin AuditMixin on NamedService {
  String audited({required String label, bool excited = false}) {
    return '[audit] ${greet(label: label, excited: excited)}';
  }
}

class AppConfig {
  const AppConfig({
    required this.appName,
    required this.mode,
    required this.enableDiagnostics,
  });

  final String appName;
  final ExampleMode mode;
  final bool enableDiagnostics;
}

@Tag('app-class')
class ExampleApp with Lifecycle {
  ExampleApp(this.config);

  final AppConfig config;

  @Tag('app-field')
  final String _secretToken = 'vault-token';

  @override
  Future<void> start() async {
    if (config.enableDiagnostics) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  @override
  Future<void> stop() async {}

  String secretSummary(FancyRenderer renderer) {
    return '${renderer.reveal()}|$_secretToken|${renderer.audited(label: 'mix', excited: true)}';
  }
}

class GreeterService extends NamedService with AuditMixin {
  @override
  String greet({required String label, bool excited = false}) {
    final suffix = excited ? '!' : '';
    return 'Hello $label$suffix';
  }
}

@Tag('renderer-class')
class FancyRenderer extends NamedService with AuditMixin {
  @Tag('renderer-field')
  final String prefix;

  @Tag('renderer-private-field')
  final String _secret = 'renderer-secret';

  @Tag('renderer-constructor')
  FancyRenderer({required this.prefix});

  @override
  @Tag('renderer-method')
  String greet({required String label, bool excited = false}) {
    return render(label: label, excited: excited);
  }

  String render({required String label, bool excited = false}) {
    final suffix = excited ? '!' : '';
    return '$prefix $label$suffix';
  }

  String reveal() => _secret;

  @override
  String toString() => 'FancyRenderer(prefix: $prefix)';
}

class MessageHolder {
  String message = 'seed-message';
}

class AliasHub {
  static final String Function({required String value, bool debug})
  finalTopLevelAlias = topLevelNamed;

  static final int Function({required int value, bool debug})
  finalGenericAlias = genericEcho<int>;

  static final RedirectPayload<String> Function({
    required String value,
    bool debug,
  })
  finalFactoryAlias = RedirectPayload<String>.redirect;

  static final RedirectPayload<int> Function({required int value, bool debug})
  finalInstantiatedFactoryAlias = RedirectPayload<int>.redirect;
}

class Payload {
  @Tag('payload-field')
  final String value;

  @Tag('payload-constructor')
  Payload.named({required this.value, bool debug = false});

  String describe() => 'Payload($value)';
}

class RedirectPayload<T> {
  final T value;

  RedirectPayload.named({required this.value, bool debug = false});

  factory RedirectPayload.redirect({required T value, bool debug}) =
      RedirectPayload<T>.named;

  String describe() => 'Redirect($value)';
}

class EntryPointPayload {
  final String value;

  @pragma('vm:entry-point')
  EntryPointPayload.named({required this.value, bool debug = false});

  String describe() => 'EntryPointPayload($value)';
}

class EntryPointService {
  @pragma('vm:entry-point')
  String callback({required String label, bool excited = false}) {
    return excited ? 'entry:$label!' : 'entry:$label';
  }

  @pragma('vm:entry-point')
  EntryPointPayload createPayload({required String value, bool debug = false}) {
    return EntryPointPayload.named(value: value, debug: debug);
  }
}

class _UnusedCase {
  const _UnusedCase(this.secret);

  final String secret;

  String reveal() => 'unused:$secret';
}

int _unusedFunction(int value) => value * 2 + 1;
