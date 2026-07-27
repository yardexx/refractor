import 'package:kernel/kernel.dart';
import 'package:refractor/src/config/model/refractor_config.dart';
import 'package:refractor/src/engine/passes/rename/planning/name_generator/sequential_generator.dart';
import 'package:refractor/src/engine/passes/rename/planning/rename_planner.dart';
import 'package:refractor/src/engine/passes/rename/selection/rename_selector.dart';
import 'package:refractor/src/policy/policy_resolver.dart';
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
      final policy = PolicyResolver().resolve(
        component: component,
        config: RefractorConfig(passes: [resolvedConfig]),
        projectScope: projectScope,
      );
      return RenameSelector(
        policy: policy.rename,
        projectScope: projectScope,
      );
    }

    RenamePlanner makePlanner({bool overloading = false}) {
      return RenamePlanner(
        generator: SequentialGenerator(),
        overloading: overloading,
      );
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
      final plan = await makePlanner().plan(component, selection);

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
        final plan = await makePlanner().plan(component, selection);

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

      final firstPlan = await planner.plan(component, selection);
      final secondPlan = await planner.plan(component, selection);

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
      final plan = await makePlanner().plan(component, selection);

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

        final first = await makePlanner().plan(component, selection);
        final second = await makePlanner().plan(component, selection);

        expect(first.mapping.classes[cls], equals(second.mapping.classes[cls]));
      },
    );

    test('overloading reuses names for unrelated instance families', () async {
      final left = Class(name: 'Left', fileUri: userLib.fileUri)
        ..addProcedure(
          Procedure(
            Name('alpha'),
            ProcedureKind.Method,
            FunctionNode(EmptyStatement()),
            fileUri: userLib.fileUri,
          ),
        );
      final right = Class(name: 'Right', fileUri: userLib.fileUri)
        ..addProcedure(
          Procedure(
            Name('beta'),
            ProcedureKind.Method,
            FunctionNode(EmptyStatement()),
            fileUri: userLib.fileUri,
          ),
        );
      userLib
        ..addClass(left)
        ..addClass(right);

      final component = makeComponent(coreLib: coreLib, userLib: userLib);
      final selection = makeSelector(component).select(component);

      final plan = await makePlanner(
        overloading: true,
      ).plan(component, selection);

      expect(
        plan.mapping.members[left.procedures.single]!.text,
        equals(plan.mapping.members[right.procedures.single]!.text),
      );
    });

    test('overloading keeps same-class families in separate slots', () async {
      final cls = Class(name: 'Svc', fileUri: userLib.fileUri)
        ..addProcedure(
          Procedure(
            Name('alpha'),
            ProcedureKind.Method,
            FunctionNode(EmptyStatement()),
            fileUri: userLib.fileUri,
          ),
        )
        ..addProcedure(
          Procedure(
            Name('beta'),
            ProcedureKind.Method,
            FunctionNode(EmptyStatement()),
            fileUri: userLib.fileUri,
          ),
        );
      userLib.addClass(cls);

      final component = makeComponent(coreLib: coreLib, userLib: userLib);
      final selection = makeSelector(component).select(component);

      final plan = await makePlanner(
        overloading: true,
      ).plan(component, selection);

      expect(
        plan.mapping.members[cls.procedures[0]]!.text,
        isNot(equals(plan.mapping.members[cls.procedures[1]]!.text)),
      );
    });

    test('overloading does not merge interface-connected families', () async {
      final ifaceA = Class(name: 'IA', fileUri: userLib.fileUri)
        ..addProcedure(
          Procedure(
            Name('alpha'),
            ProcedureKind.Method,
            FunctionNode(EmptyStatement()),
            fileUri: userLib.fileUri,
          ),
        );
      final ifaceB = Class(name: 'IB', fileUri: userLib.fileUri)
        ..addProcedure(
          Procedure(
            Name('beta'),
            ProcedureKind.Method,
            FunctionNode(EmptyStatement()),
            fileUri: userLib.fileUri,
          ),
        );
      userLib
        ..addClass(ifaceA)
        ..addClass(ifaceB);
      final impl =
          Class(
              name: 'Impl',
              fileUri: userLib.fileUri,
              implementedTypes: [
                ifaceA.asThisSupertype,
                ifaceB.asThisSupertype,
              ],
            )
            ..addProcedure(
              Procedure(
                Name('alpha'),
                ProcedureKind.Method,
                FunctionNode(EmptyStatement()),
                fileUri: userLib.fileUri,
              ),
            )
            ..addProcedure(
              Procedure(
                Name('beta'),
                ProcedureKind.Method,
                FunctionNode(EmptyStatement()),
                fileUri: userLib.fileUri,
              ),
            );
      userLib.addClass(impl);

      final component = makeComponent(coreLib: coreLib, userLib: userLib);
      final selection = makeSelector(component).select(component);

      final plan = await makePlanner(
        overloading: true,
      ).plan(component, selection);

      expect(
        plan.mapping.members[ifaceA.procedures.single]!.text,
        isNot(equals(plan.mapping.members[ifaceB.procedures.single]!.text)),
      );
      expect(
        plan.mapping.members[impl.procedures[0]]!.text,
        isNot(equals(plan.mapping.members[impl.procedures[1]]!.text)),
      );
    });

    test('overloading keeps private families isolated by library', () async {
      final libA = makeUserLibrary('src/a.dart');
      final libB = makeUserLibrary('src/b.dart');

      final classA = Class(name: 'A', fileUri: libA.fileUri)
        ..addProcedure(
          Procedure(
            Name('_alpha', libA),
            ProcedureKind.Method,
            FunctionNode(EmptyStatement()),
            fileUri: libA.fileUri,
          ),
        )
        ..addProcedure(
          Procedure(
            Name('_beta', libA),
            ProcedureKind.Method,
            FunctionNode(EmptyStatement()),
            fileUri: libA.fileUri,
          ),
        );
      final classB = Class(name: 'B', fileUri: libB.fileUri)
        ..addProcedure(
          Procedure(
            Name('_gamma', libB),
            ProcedureKind.Method,
            FunctionNode(EmptyStatement()),
            fileUri: libB.fileUri,
          ),
        )
        ..addProcedure(
          Procedure(
            Name('_delta', libB),
            ProcedureKind.Method,
            FunctionNode(EmptyStatement()),
            fileUri: libB.fileUri,
          ),
        );
      libA.addClass(classA);
      libB.addClass(classB);

      final component = Component(libraries: [coreLib, libA, libB])
        ..setMainMethodAndMode(null, true);
      final selection = makeSelector(component).select(component);

      final plan = await makePlanner(
        overloading: true,
      ).plan(component, selection);

      expect(
        plan.mapping.members[classA.procedures[0]]!.text,
        isNot(equals(plan.mapping.members[classA.procedures[1]]!.text)),
      );
      expect(
        plan.mapping.members[classB.procedures[0]]!.text,
        isNot(equals(plan.mapping.members[classB.procedures[1]]!.text)),
      );
      expect(plan.mapping.members[classA.procedures[0]]!.library, same(libA));
      expect(plan.mapping.members[classB.procedures[0]]!.library, same(libB));
    });
  });
}
