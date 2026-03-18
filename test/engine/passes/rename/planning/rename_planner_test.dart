import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_pass_options.dart';
import 'package:refractor/src/engine/passes/rename/planning/rename_planner.dart';
import 'package:refractor/src/engine/policy/obfuscation_policy_resolver.dart';
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

    RenamePlanner makePlanner(
      Component component, {
      RenamePassOptions? options,
    }) {
      final resolvedOptions = options ?? const RenamePassOptions();
      final policy = ObfuscationPolicyResolver().resolve(
        component,
        makeObfuscationTarget(),
        renameOptions: resolvedOptions,
      );
      return RenamePlanner(policy: policy);
    }

    test('groups related instance members into one family', () {
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
      final plan = makePlanner(component).plan(component);

      expect(plan.memberFamilies, hasLength(1));
      expect(
        plan.memberFamilies.single.members,
        containsAll([baseMethod, childMethod]),
      );
    });

    test(
      'extracts singleton members for top-level, static, and constructors',
      () {
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
        final plan = makePlanner(component).plan(component);

        expect(
          plan.singletonMembers,
          containsAll([topLevel, staticMethod, constructor]),
        );
      },
    );

    test('excludes parameters of preserved main from variable planning', () {
      final keptParam = VariableDeclaration('debug');
      final keptLocal = VariableDeclaration('localValue');
      final mainProcedure = Procedure(
        Name('main'),
        ProcedureKind.Method,
        FunctionNode(
          Block([keptLocal]),
          namedParameters: [keptParam],
        ),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(mainProcedure);

      final otherParam = VariableDeclaration('count');
      final otherProcedure = Procedure(
        Name('work'),
        ProcedureKind.Method,
        FunctionNode(
          EmptyStatement(),
          positionalParameters: [otherParam],
          requiredParameterCount: 1,
        ),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(otherProcedure);

      final component = makeComponent(coreLib: coreLib, userLib: userLib);
      final plan = makePlanner(component).plan(component);

      expect(plan.variables, isNot(contains(keptParam)));
      expect(plan.variables, isNot(contains(keptLocal)));
      expect(plan.variables, contains(otherParam));
    });

    test('keeps private member families scoped by library', () {
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
      final plan = makePlanner(component).plan(component);

      expect(plan.memberFamilies, hasLength(2));
    });
  });
}
