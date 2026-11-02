import 'package:refractor/src/engine/kernel/runtime_helpers.dart';
import 'package:refractor/src/engine/pass/config/pass_config.dart';
import 'package:refractor/src/engine/pass/pass_registry.dart';
import 'package:refractor/src/engine/passes/arithmetic_mangle/arithmetic_mangle_pass.dart';
import 'package:refractor/src/engine/passes/arithmetic_mangle/config/arithmetic_mangle_config.dart';
import 'package:refractor/src/engine/passes/arithmetic_mangle/config/arithmetic_mangle_definition.dart';
import 'package:refractor/src/engine/passes/control_flow_flatten/config/control_flow_flatten_config.dart';
import 'package:refractor/src/engine/passes/control_flow_flatten/config/control_flow_flatten_definition.dart';
import 'package:refractor/src/engine/passes/control_flow_flatten/control_flow_flatten_pass.dart';
import 'package:refractor/src/engine/passes/dead_code/config/dead_code_config.dart';
import 'package:refractor/src/engine/passes/dead_code/config/dead_code_definition.dart';
import 'package:refractor/src/engine/passes/dead_code/dead_code_pass.dart';
import 'package:refractor/src/engine/passes/opaque_predicate/config/opaque_predicate_config.dart';
import 'package:refractor/src/engine/passes/opaque_predicate/config/opaque_predicate_definition.dart';
import 'package:refractor/src/engine/passes/opaque_predicate/opaque_predicate_pass.dart';
import 'package:test/test.dart';

import '../../helpers/kernel_helpers.dart';

final class _OtherConfig extends PassConfig {
  const _OtherConfig();
}

void main() {
  group('OpaquePredicateDefinition', () {
    const definition = OpaquePredicateDefinition();

    test('name and keep sources', () {
      expect(definition.name, 'opaque_predicate');
      expect(definition.keepSources, isNotEmpty);
    });

    test('parses config defaults and overrides', () {
      expect(definition.parseConfig(const {}).enabled, isTrue);
      final config = definition.parseConfig(const {
        'enabled': false,
        'seed': 9,
        'exclude': ['a/*'],
      });
      expect(config.enabled, isFalse);
      expect(config.seed, 9);
      expect(config.exclude, ['a/*']);
    });

    test('supports its own config and creates its pass', () {
      expect(definition.supports(const OpaquePredicatePassConfig()), isTrue);
      expect(definition.supports(const _OtherConfig()), isFalse);
      final pass = definition.createPass(
        config: const OpaquePredicatePassConfig(),
        scope: makeObfuscationScope(),
        helpers: RuntimeHelpers.none,
      );
      expect(pass, isA<OpaquePredicatePass>());
    });
  });

  group('ArithmeticMangleDefinition', () {
    const definition = ArithmeticMangleDefinition();

    test('name and keep sources', () {
      expect(definition.name, 'arithmetic_mangle');
      expect(definition.keepSources, isNotEmpty);
    });

    test('parses config defaults and overrides', () {
      expect(definition.parseConfig(const {}).enabled, isTrue);
      final config = definition.parseConfig(const {
        'enabled': false,
        'seed': 9,
        'exclude': ['a/*'],
      });
      expect(config.enabled, isFalse);
      expect(config.seed, 9);
      expect(config.exclude, ['a/*']);
    });

    test('supports its own config and creates its pass', () {
      expect(definition.supports(const ArithmeticManglePassConfig()), isTrue);
      expect(definition.supports(const _OtherConfig()), isFalse);
      final pass = definition.createPass(
        config: const ArithmeticManglePassConfig(),
        scope: makeObfuscationScope(),
        helpers: RuntimeHelpers.none,
      );
      expect(pass, isA<ArithmeticManglePass>());
    });
  });

  group('ControlFlowFlattenDefinition', () {
    const definition = ControlFlowFlattenDefinition();

    test('name and keep sources', () {
      expect(definition.name, 'control_flow_flatten');
      expect(definition.keepSources, isNotEmpty);
    });

    test('parses config defaults and overrides', () {
      expect(definition.parseConfig(const {}).enabled, isTrue);
      final config = definition.parseConfig(const {
        'enabled': false,
        'seed': 9,
        'exclude': ['a/*'],
      });
      expect(config.enabled, isFalse);
      expect(config.seed, 9);
      expect(config.exclude, ['a/*']);
    });

    test('supports its own config and creates its pass', () {
      expect(
        definition.supports(const ControlFlowFlattenPassConfig()),
        isTrue,
      );
      expect(definition.supports(const _OtherConfig()), isFalse);
      final pass = definition.createPass(
        config: const ControlFlowFlattenPassConfig(),
        scope: makeObfuscationScope(),
        helpers: RuntimeHelpers.none,
      );
      expect(pass, isA<ControlFlowFlattenPass>());
    });
  });

  group('DeadCodeDefinition', () {
    const definition = DeadCodeDefinition();

    test('name and keep sources', () {
      expect(definition.name, 'dead_code');
      expect(definition.keepSources, isNotEmpty);
    });

    test('parses config defaults and overrides', () {
      expect(definition.parseConfig(const {}).enabled, isTrue);
      final config = definition.parseConfig(const {
        'enabled': false,
        'seed': 9,
        'exclude': ['a/*'],
      });
      expect(config.enabled, isFalse);
      expect(config.seed, 9);
      expect(config.exclude, ['a/*']);
    });

    test('supports its own config and creates its pass', () {
      expect(definition.supports(const DeadCodePassConfig()), isTrue);
      expect(definition.supports(const _OtherConfig()), isFalse);
      final pass = definition.createPass(
        config: const DeadCodePassConfig(),
        scope: makeObfuscationScope(),
        helpers: RuntimeHelpers.none,
      );
      expect(pass, isA<DeadCodePass>());
    });
  });

  test('all layer-2 passes are registered', () {
    final names = defaultPassRegistry.definitions
        .map((definition) => definition.name)
        .toList();
    expect(
      names,
      containsAll([
        'opaque_predicate',
        'arithmetic_mangle',
        'control_flow_flatten',
        'dead_code',
      ]),
    );
  });
}
