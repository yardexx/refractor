import 'package:kernel/kernel.dart';
import 'package:refractor/src/config/model/refractor_config.dart';
import 'package:refractor/src/engine/passes/rename/config/rename_definition.dart';
import 'package:refractor/src/engine/passes/rename/planning/name_generator/sequential_generator.dart';
import 'package:refractor/src/engine/passes/rename/planning/rename_planner.dart';
import 'package:refractor/src/engine/passes/rename/selection/rename_selector.dart';
import 'package:refractor/src/policy/keep_resolver.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';
import 'package:test/test.dart';

import '../../../../helpers/kernel_helpers.dart';

void main() {
  group('RenamePlanner', () {
    late Library coreLib;
    late Library userLib;

    setUp(() {
      coreLib = makeDartCoreLibrary();
      userLib = makeUserLibrary();
    });

    RenameSelector makeSelector(
      Component component, {
      RenamePassConfig? config,
    }) {
      final resolvedConfig = config ?? const RenamePassConfig();
      final projectScope = makeProjectScope();
      final keepResolver = KeepResolver(
        component: component,
        projectScope: projectScope,
        globalExcludes: RefractorConfig(
          passes: [resolvedConfig],
        ).excludePatterns,
      );
      return RenameSelector(
        scope: ObfuscationScope(
          project: projectScope,
          keep: keepResolver.resolve(
            const RenameDefinition().keepSources,
            resolvedConfig.exclude,
          ),
        ),
      );
    }

    RenamePlanner makePlanner() {
      return RenamePlanner(generator: SequentialGenerator());
    }

    test('assigns the same mapped name to related instance members', () async {
      final base = Class(name: 'Base', fileUri: userLib.fileUri);
      final baseMethod = makeProcedure('run', base);
      userLib.addClass(base);

      final child = Class(
        name: 'Child',
        fileUri: userLib.fileUri,
        supertype: base.asThisSupertype,
      );
      final childMethod = makeProcedure('run', child);
      userLib.addClass(child);

      final component = makeComponent(coreLib: coreLib, userLib: userLib);
      final selection = makeSelector(component).select(component);
      final plan = makePlanner().plan(component, selection);

      expect(
        plan.mapping.members[baseMethod]!.text,
        equals(plan.mapping.members[childMethod]!.text),
      );
    });

    test(
      'creates planned rename entries for top-level, static, and constructors',
      () async {
        final topLevel = Procedure(
          Name('topLevel'),
          ProcedureKind.Method,
          FunctionNode(EmptyStatement()),
          fileUri: userLib.fileUri,
        );
        userLib.addProcedure(topLevel);

        final cls = Class(name: 'Svc', fileUri: userLib.fileUri);
        final staticMethod = Procedure(
          Name('helper'),
          ProcedureKind.Method,
          FunctionNode(EmptyStatement()),
          fileUri: userLib.fileUri,
          isStatic: true,
        );
        final constructor = Constructor(
          FunctionNode(EmptyStatement()),
          name: Name('create'),
          fileUri: userLib.fileUri,
        );
        cls
          ..addProcedure(staticMethod)
          ..addConstructor(constructor);
        userLib.addClass(cls);

        final component = makeComponent(coreLib: coreLib, userLib: userLib);
        final selection = makeSelector(component).select(component);
        final plan = makePlanner().plan(component, selection);

        expect(
          plan.mapping.members.keys,
          containsAll([topLevel, staticMethod, constructor]),
        );
      },
    );

    test('can be reused without leaking prior planning state', () async {
      final firstClass = Class(name: 'First', fileUri: userLib.fileUri)
        ..addProcedure(
          Procedure(
            Name('first'),
            ProcedureKind.Method,
            FunctionNode(EmptyStatement()),
            fileUri: userLib.fileUri,
            isStatic: true,
          ),
        );
      userLib.addClass(firstClass);

      final component = makeComponent(coreLib: coreLib, userLib: userLib);
      final selection = makeSelector(component).select(component);
      final planner = makePlanner();

      final firstPlan = planner.plan(component, selection);
      final secondPlan = planner.plan(component, selection);

      expect(
        secondPlan.mapping.classes.length,
        firstPlan.mapping.classes.length,
      );
      expect(
        secondPlan.mapping.members.length,
        firstPlan.mapping.members.length,
      );
      expect(
        secondPlan.mapping.variables.length,
        firstPlan.mapping.variables.length,
      );
    });

    test('keeps private member renames scoped by library', () async {
      final libA = makeUserLibrary('src/a.dart');
      final libB = makeUserLibrary();

      final base = Class(name: 'Base', fileUri: libA.fileUri);
      final baseMethod = Procedure(
        Name('_hidden', libA),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: libA.fileUri,
      );
      base.addProcedure(baseMethod);
      libA.addClass(base);

      final derived = Class(
        name: 'Derived',
        fileUri: libB.fileUri,
        supertype: base.asThisSupertype,
      );
      final derivedMethod = Procedure(
        Name('_hidden', libB),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: libB.fileUri,
      );
      derived.addProcedure(derivedMethod);
      libB.addClass(derived);

      final component = Component(libraries: [coreLib, libA, libB])
        ..setMainMethodAndMode(null, true);
      final selection = makeSelector(component).select(component);
      final plan = makePlanner().plan(component, selection);

      expect(plan.mapping.members[baseMethod]!.library, same(libA));
      expect(plan.mapping.members[derivedMethod]!.library, same(libB));
    });

    test(
      'produces deterministic final mapping for a fixed generator',
      () async {
        final cls = Class(name: 'Tracker', fileUri: userLib.fileUri);
        userLib.addClass(cls);
        final component = makeComponent(coreLib: coreLib, userLib: userLib);
        final selection = makeSelector(component).select(component);

        final first = makePlanner().plan(component, selection);
        final second = makePlanner().plan(component, selection);

        expect(first.mapping.classes[cls], equals(second.mapping.classes[cls]));
      },
    );
  });
}
