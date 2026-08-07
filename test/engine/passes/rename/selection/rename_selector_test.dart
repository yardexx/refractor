import 'package:kernel/kernel.dart';
import 'package:refractor/src/config/model/refractor_config.dart';
import 'package:refractor/src/engine/passes/rename/config/rename_definition.dart';
import 'package:refractor/src/engine/passes/rename/selection/rename_selector.dart';
import 'package:refractor/src/policy/keep_resolver.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';
import 'package:test/test.dart';

import '../../../../helpers/kernel_helpers.dart';

void main() {
  group('RenameSelector', () {
    late Library coreLib;
    late Library annotationLib;
    late Library userLib;

    setUp(() {
      coreLib = makeDartCoreLibrary();
      annotationLib = makeRefractorAnnotationLibrary();
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

    test(
      'excludes parameters of preserved main but still collects local '
      'variables',
      () {
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
        expect(selection.variables, contains(keptLocal));
        expect(selection.variables, contains(otherParam));
      },
    );

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

    test(
      'kept project supertype members protect overriding subclass members',
      () {
        final base = Class(name: 'Base', fileUri: userLib.fileUri);
        final keptMethod = Procedure(
          Name('render'),
          ProcedureKind.Method,
          FunctionNode(EmptyStatement()),
          fileUri: userLib.fileUri,
        )..addAnnotation(makeRefractorKeepAnnotation(annotationLib));
        base.addProcedure(keptMethod);
        userLib.addClass(base);

        final child = Class(
          name: 'Child',
          fileUri: userLib.fileUri,
          supertype: base.asThisSupertype,
        );
        final overridingMethod = Procedure(
          Name('render'),
          ProcedureKind.Method,
          FunctionNode(EmptyStatement()),
          fileUri: userLib.fileUri,
        );
        child.addProcedure(overridingMethod);
        userLib.addClass(child);

        final component = makeComponent(
          coreLib: coreLib,
          userLib: userLib,
          extraLibraries: [annotationLib],
        );
        final selection = makeSelector(component).select(component);

        expect(selection.instanceMembersByClass[child], isNotNull);
        expect(
          selection.instanceMembersByClass[child],
          isNot(contains(overridingMethod)),
        );
      },
    );
  });
}
