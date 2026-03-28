import 'package:kernel/kernel.dart';
import 'package:refractor/src/config/model/refractor_config.dart';
import 'package:refractor/src/engine/passes/rename/selection/rename_selector.dart';
import 'package:refractor/src/policy/policy_resolver.dart';
import 'package:test/test.dart';

import '../../../../helpers/kernel_helpers.dart';

void main() {
  group('RenameSelector', () {
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

    test(
      'collects singleton members for top-level, static, and constructors',
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
        final selection = makeSelector(component).select(component);

        expect(
          selection.singletonMembers,
          containsAll([topLevel, staticMethod, constructor]),
        );
      },
    );

    test('excludes parameters of preserved main from selection variables', () {
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
      final selection = makeSelector(component).select(component);

      expect(selection.variables, isNot(contains(keptParam)));
      expect(selection.variables, isNot(contains(keptLocal)));
      expect(selection.variables, contains(otherParam));
    });

    test('reusing a selector does not leak selection state between runs', () {
      final componentOne = makeComponent(coreLib: coreLib, userLib: userLib);
      final selector = makeSelector(componentOne);

      final classOne = Class(name: 'First', fileUri: userLib.fileUri);
      userLib.addClass(classOne);
      final firstSelection = selector.select(componentOne);
      expect(firstSelection.classes, contains(classOne));

      final secondUserLib = makeUserLibrary();
      final classTwo = Class(name: 'Second', fileUri: secondUserLib.fileUri);
      secondUserLib.addClass(classTwo);
      final componentTwo = makeComponent(
        coreLib: makeDartCoreLibrary(),
        userLib: secondUserLib,
      );
      final secondSelection = selector.select(componentTwo);

      expect(secondSelection.classes, contains(classTwo));
      expect(secondSelection.classes, isNot(contains(classOne)));
    });

    test(
      'skips renaming synthetic anonymous mixin classes but keeps members',
      () {
      final anonymousMixin = Class(
        name: '_Greeter&Object&Prefixed',
        fileUri: userLib.fileUri,
        isAnonymousMixin: true,
      );
      final syntheticMethod = Procedure(
        Name('format'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      anonymousMixin.addProcedure(syntheticMethod);

      final regularClass = Class(name: 'Greeter', fileUri: userLib.fileUri);
      userLib
        ..addClass(anonymousMixin)
        ..addClass(regularClass);

      final component = makeComponent(coreLib: coreLib, userLib: userLib);
      final selection = makeSelector(component).select(component);

      expect(selection.classes, contains(regularClass));
      expect(selection.classes, isNot(contains(anonymousMixin)));
      expect(selection.singletonMembers, isNot(contains(syntheticMethod)));
      expect(
        selection.instanceMembersByClass[anonymousMixin],
        contains(syntheticMethod),
      );
      },
    );
  });
}
