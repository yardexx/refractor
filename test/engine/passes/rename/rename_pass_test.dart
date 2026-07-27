import 'package:kernel/kernel.dart';
import 'package:refractor/src/config/model/refractor_config.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/passes/rename/rename_pass.dart';
import 'package:refractor/src/engine/passes/rename/reporting/rename_artifact.dart';
import 'package:refractor/src/engine/passes/rename/reporting/rename_mapping.dart';
import 'package:refractor/src/policy/policy_resolver.dart';
import 'package:refractor/src/policy/rename_policy_view.dart';
import 'package:refractor/src/project/project_scope.dart';
import 'package:test/test.dart';

import '../../../helpers/kernel_helpers.dart';

void main() {
  group('RenamePass', () {
    late Library coreLib;
    late Library annotationLib;
    late Library userLib;
    late Component component;
    late ProjectScope projectScope;

    setUp(() {
      coreLib = makeDartCoreLibrary();
      annotationLib = makeRefractorAnnotationLibrary();
      userLib = makeUserLibrary();
      projectScope = makeProjectScope();
    });

    RenamePass makePass(
      Component component, {
      RenamePassConfig config = const RenamePassConfig(),
    }) {
      final policy = PolicyResolver().resolve(
        component: component,
        config: RefractorConfig(passes: [config]),
        projectScope: projectScope,
      );
      return RenamePass(
        config: config,
        policy: policy.rename,
        projectScope: projectScope,
      );
    }

    Future<RenameMapping> runPass([
      RenamePassConfig config = const RenamePassConfig(),
    ]) async {
      component = makeComponent(
        coreLib: coreLib,
        userLib: userLib,
        extraLibraries: [annotationLib],
      );
      final result = await makePass(component, config: config).run(component);
      expect(result, isA<PassSucceeded>());
      return ((result as PassSucceeded).artifact! as RenameArtifact).mapping;
    }

    test('returns stable pass result shape with report and artifact', () async {
      final cls = Class(name: 'Tracker', fileUri: userLib.fileUri);
      userLib.addClass(cls);

      component = makeComponent(
        coreLib: coreLib,
        userLib: userLib,
        extraLibraries: [annotationLib],
      );
      final result = await makePass(component).run(component);

      expect(result, isA<PassSucceeded>());
      final success = result as PassSucceeded;
      expect(success.report.passName, 'rename');
      expect(success.artifact, isA<RenameArtifact>());
    });

    test('rename artifact is serializable to JSON data', () async {
      final cls = Class(name: 'Tracker', fileUri: userLib.fileUri);
      userLib.addClass(cls);

      final mapping = await runPass();

      expect(RenameArtifact(mapping: mapping).toJson(), {
        'symbol_map': {
          for (final entry in mapping.symbolMap.entries)
            entry.key: entry.value.single,
        },
      });
    });

    test('renames class name in user library', () async {
      final cls = Class(name: 'MyService', fileUri: userLib.fileUri);
      userLib.addClass(cls);

      await runPass();

      expect(cls.name, isNot('MyService'));
    });

    test('renames procedure name in user library', () async {
      final proc = Procedure(
        Name('doWork'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(proc);

      await runPass();

      expect(proc.name.text, isNot('doWork'));
    });

    test('renames field name in user library', () async {
      final cls = Class(name: 'Svc', fileUri: userLib.fileUri);
      final field = Field.mutable(
        Name('_secret', userLib),
        fileUri: userLib.fileUri,
      );
      cls.addField(field);
      userLib.addClass(cls);

      await runPass();

      expect(field.name.text, isNot('_secret'));
      expect(field.name.text, startsWith('_'));
    });

    test('skips dart: libraries entirely', () async {
      final coreClass = coreLib.classes.firstWhere((c) => c.name == 'int');

      await runPass();

      expect(coreClass.name, equals('int'));
    });

    test('skips non-project package: libraries', () async {
      final otherUri = Uri.parse('package:other_pkg/other.dart');
      final otherLib = Library(otherUri, fileUri: otherUri);
      final cls = Class(name: 'ExternalClass', fileUri: otherUri);
      otherLib.addClass(cls);

      component = Component(libraries: [coreLib, userLib, otherLib])
        ..setMainMethodAndMode(null, true);
      await makePass(component).run(component);

      expect(cls.name, equals('ExternalClass'));
    });

    test('keeps the component main procedure unchanged', () async {
      final mainProc = Procedure(
        Name('main'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(mainProc);

      component = Component(libraries: [coreLib, userLib])
        ..setMainMethodAndMode(mainProc.reference, true);
      final result = await makePass(component).run(component);

      expect(result, isA<PassSucceeded>());

      expect(mainProc.name.text, equals('main'));
    });

    test(
      'renames procedures named main when they are not the entrypoint',
      () async {
        final mainProc = Procedure(
          Name('main'),
          ProcedureKind.Method,
          FunctionNode(EmptyStatement()),
          fileUri: userLib.fileUri,
        );
        userLib.addProcedure(mainProc);

        await runPass();

        expect(mainProc.name.text, isNot('main'));
      },
    );

    test(
      'Refractor.keep annotation prevents rename of annotated node',
      () async {
        final cls = Class(name: 'KeepMe', fileUri: userLib.fileUri)
          ..addAnnotation(makeRefractorKeepAnnotation(annotationLib));
        userLib.addClass(cls);

        await runPass();

        expect(cls.name, equals('KeepMe'));
      },
    );

    test('field and getter with same name get same obfuscated name', () async {
      final cls = Class(name: 'Svc', fileUri: userLib.fileUri);
      final field = Field.mutable(
        Name('value'),
        fileUri: userLib.fileUri,
      );
      final getter = Procedure(
        Name('value'),
        ProcedureKind.Getter,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      cls
        ..addField(field)
        ..addProcedure(getter);
      userLib.addClass(cls);

      await runPass();

      expect(field.name.text, equals(getter.name.text));
    });

    test(
      'InstanceGet.name is updated when interfaceTarget is renamed',
      () async {
        final cls = Class(name: 'Svc', fileUri: userLib.fileUri);
        final field = Field.mutable(
          Name('data'),
          fileUri: userLib.fileUri,
        );
        cls.addField(field);

        final thisVar = VariableDeclaration('this');
        final instanceGet = InstanceGet(
          InstanceAccessKind.Instance,
          VariableGet(thisVar),
          Name('data'),
          resultType: const DynamicType(),
          interfaceTarget: field,
        );
        final body = ReturnStatement(instanceGet);
        final reader = Procedure(
          Name('read'),
          ProcedureKind.Method,
          FunctionNode(body),
          fileUri: userLib.fileUri,
        );
        cls.addProcedure(reader);
        userLib.addClass(cls);

        await runPass();

        expect(instanceGet.name.text, equals(field.name.text));
        expect(instanceGet.name.text, isNot('data'));
      },
    );

    test('symbolMap records obfuscated to original mappings', () async {
      final cls = Class(name: 'Tracker', fileUri: userLib.fileUri);
      userLib.addClass(cls);

      final mapping = await runPass();

      expect(mapping.symbolMap, isNotEmpty);
      expect(mapping.originalsFor(cls.name), contains('Tracker'));
    });

    test('returns report metrics for renamed declarations', () async {
      final cls = Class(name: 'Tracker', fileUri: userLib.fileUri);
      userLib.addClass(cls);

      component = makeComponent(coreLib: coreLib, userLib: userLib);
      final result = await makePass(component).run(component);

      expect(result, isA<PassSucceeded>());
      expect(result.report.passName, 'rename');
      expect(result.report.metadata.keys, [
        'classes',
        'members',
        'variables',
      ]);
      expect(result.report.metadata['classes'], '1');
    });

    test('renames named constructor', () async {
      final cls = Class(name: 'MyClass', fileUri: userLib.fileUri);
      final ctor = Constructor(
        FunctionNode(EmptyStatement()),
        name: Name('create'),
        fileUri: userLib.fileUri,
      );
      cls.addConstructor(ctor);
      userLib.addClass(cls);

      await runPass();

      expect(ctor.name.text, isNot('create'));
    });

    test('does not rename default (unnamed) constructor', () async {
      final cls = Class(name: 'MyClass', fileUri: userLib.fileUri);
      final ctor = Constructor(
        FunctionNode(EmptyStatement()),
        name: Name(''),
        fileUri: userLib.fileUri,
      );
      cls.addConstructor(ctor);
      userLib.addClass(cls);

      await runPass();

      expect(ctor.name.text, equals(''));
    });

    test('constructor with Refractor.keep is not renamed', () async {
      final cls = Class(name: 'MyClass', fileUri: userLib.fileUri);
      final ctor = Constructor(
        FunctionNode(EmptyStatement()),
        name: Name('kept'),
        fileUri: userLib.fileUri,
      )..addAnnotation(makeRefractorKeepAnnotation(annotationLib));
      cls.addConstructor(ctor);
      userLib.addClass(cls);

      await runPass();

      expect(ctor.name.text, equals('kept'));
    });

    test('StaticInvocation still resolves after procedure rename', () async {
      final proc = Procedure(
        Name('compute'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
        isStatic: true,
      );
      userLib.addProcedure(proc);

      final invocation = StaticInvocation(proc, Arguments.empty());
      final wrapper = Procedure(
        Name('caller'),
        ProcedureKind.Method,
        FunctionNode(ExpressionStatement(invocation)),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(wrapper);

      await runPass();

      expect(proc.name.text, isNot('compute'));
      expect(invocation.target, same(proc));
    });

    test('StaticGet still resolves after field rename', () async {
      final field = Field.mutable(
        Name('config'),
        fileUri: userLib.fileUri,
        isStatic: true,
      );
      userLib.addField(field);

      final staticGet = StaticGet(field);
      final wrapper = Procedure(
        Name('reader'),
        ProcedureKind.Method,
        FunctionNode(ReturnStatement(staticGet)),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(wrapper);

      await runPass();

      expect(field.name.text, isNot('config'));
      expect(staticGet.target, same(field));
    });

    test(
      'ConstructorInvocation still resolves after constructor rename',
      () async {
        final cls = Class(name: 'Widget', fileUri: userLib.fileUri);
        final ctor = Constructor(
          FunctionNode(EmptyStatement()),
          name: Name('build'),
          fileUri: userLib.fileUri,
        );
        cls.addConstructor(ctor);
        userLib.addClass(cls);

        final invocation = ConstructorInvocation(ctor, Arguments.empty());
        final wrapper = Procedure(
          Name('factory'),
          ProcedureKind.Method,
          FunctionNode(ReturnStatement(invocation)),
          fileUri: userLib.fileUri,
        );
        userLib.addProcedure(wrapper);

        await runPass();

        expect(ctor.name.text, isNot('build'));
        expect(invocation.target, same(ctor));
      },
    );

    test('SuperInitializer still resolves after constructor rename', () async {
      final baseClass = Class(name: 'Base', fileUri: userLib.fileUri);
      final baseCtor = Constructor(
        FunctionNode(EmptyStatement()),
        name: Name('named'),
        fileUri: userLib.fileUri,
      );
      baseClass.addConstructor(baseCtor);
      userLib.addClass(baseClass);

      final derivedClass = Class(
        name: 'Derived',
        fileUri: userLib.fileUri,
        supertype: InterfaceType(
          baseClass,
          Nullability.nonNullable,
        ).classNode.asThisSupertype,
      );
      final superInit = SuperInitializer(baseCtor, Arguments.empty());
      final derivedCtor = Constructor(
        FunctionNode(EmptyStatement()),
        name: Name('fromBase'),
        fileUri: userLib.fileUri,
        initializers: [superInit],
      );
      derivedClass.addConstructor(derivedCtor);
      userLib.addClass(derivedClass);

      await runPass();

      expect(baseCtor.name.text, isNot('named'));
      expect(superInit.target, same(baseCtor));
    });

    test(
      'RedirectingInitializer still resolves after constructor rename',
      () async {
        final cls = Class(name: 'Config', fileUri: userLib.fileUri);
        final primaryCtor = Constructor(
          FunctionNode(EmptyStatement()),
          name: Name('primary'),
          fileUri: userLib.fileUri,
        );
        final redirect = RedirectingInitializer(primaryCtor, Arguments.empty());
        final secondaryCtor = Constructor(
          FunctionNode(EmptyStatement()),
          name: Name('secondary'),
          fileUri: userLib.fileUri,
          initializers: [redirect],
        );
        cls
          ..addConstructor(primaryCtor)
          ..addConstructor(secondaryCtor);
        userLib.addClass(cls);

        await runPass();

        expect(primaryCtor.name.text, isNot('primary'));
        expect(redirect.target, same(primaryCtor));
      },
    );

    test('StaticSet still resolves after field rename', () async {
      final field = Field.mutable(
        Name('setting'),
        fileUri: userLib.fileUri,
        isStatic: true,
      );
      userLib.addField(field);

      final staticSet = StaticSet(field, IntLiteral(42));
      final wrapper = Procedure(
        Name('writer'),
        ProcedureKind.Method,
        FunctionNode(ExpressionStatement(staticSet)),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(wrapper);

      await runPass();

      expect(field.name.text, isNot('setting'));
      expect(staticSet.target, same(field));
    });

    test(
      'round-trip serialization succeeds after constructor rename',
      () async {
        final cls = Class(name: 'Service', fileUri: userLib.fileUri);
        final ctor = Constructor(
          FunctionNode(EmptyStatement()),
          name: Name('create'),
          fileUri: userLib.fileUri,
        );
        cls.addConstructor(ctor);
        userLib.addClass(cls);

        await runPass();

        final bytes = writeComponentToBytes(component);
        expect(bytes, isNotEmpty);

        final loaded = loadComponentFromBytes(bytes);
        final loadedLib = loaded.libraries.firstWhere(
          (l) => l.importUri.scheme == 'package',
        );
        final loadedCls = loadedLib.classes.firstWhere(
          (c) => c.constructors.isNotEmpty,
        );
        final loadedCtor = loadedCls.constructors.first;
        expect(loadedCtor.name.text, isNot('create'));
      },
    );

    test('renames local variables and parameters', () async {
      final local = VariableDeclaration(
        'localValue',
        initializer: IntLiteral(1),
      );
      final param = VariableDeclaration('count');
      final proc = Procedure(
        Name('work'),
        ProcedureKind.Method,
        FunctionNode(
          Block([
            local,
            ReturnStatement(VariableGet(param)),
          ]),
          positionalParameters: [param],
          requiredParameterCount: 1,
        ),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(proc);

      await runPass();

      expect(local.name, isNot('localValue'));
      expect(param.name, isNot('count'));
    });

    // --- Tier 1 tests ---

    test(
      'members of base and derived class get the SAME obfuscated name',
      () async {
        final baseClass = Class(name: 'Animal', fileUri: userLib.fileUri);
        final baseMethod = Procedure(
          Name('speak'),
          ProcedureKind.Method,
          FunctionNode(EmptyStatement()),
          fileUri: userLib.fileUri,
        );
        baseClass.addProcedure(baseMethod);
        userLib.addClass(baseClass);

        final derivedClass = Class(
          name: 'Dog',
          fileUri: userLib.fileUri,
          supertype: baseClass.asThisSupertype,
        );
        final derivedMethod = Procedure(
          Name('speak'),
          ProcedureKind.Method,
          FunctionNode(EmptyStatement()),
          fileUri: userLib.fileUri,
        );
        derivedClass.addProcedure(derivedMethod);
        userLib.addClass(derivedClass);

        await runPass();

        expect(baseMethod.name.text, equals(derivedMethod.name.text));
        expect(baseMethod.name.text, isNot('speak'));
      },
    );

    test(
      'members of two unrelated classes get DIFFERENT obfuscated names',
      () async {
        final classA = Class(name: 'Foo', fileUri: userLib.fileUri);
        final methodA = Procedure(
          Name('doWork'),
          ProcedureKind.Method,
          FunctionNode(EmptyStatement()),
          fileUri: userLib.fileUri,
        );
        classA.addProcedure(methodA);
        userLib.addClass(classA);

        final classB = Class(name: 'Bar', fileUri: userLib.fileUri);
        final methodB = Procedure(
          Name('compute'),
          ProcedureKind.Method,
          FunctionNode(EmptyStatement()),
          fileUri: userLib.fileUri,
        );
        classB.addProcedure(methodB);
        userLib.addClass(classB);

        await runPass();

        expect(methodA.name.text, isNot(equals(methodB.name.text)));
      },
    );

    test('fixed seed produces stable output across two runs', () async {
      Future<String> runWithSeed(int seed) async {
        final lib = makeUserLibrary();
        final cls = Class(name: 'Svc', fileUri: lib.fileUri);
        final method = Procedure(
          Name('process'),
          ProcedureKind.Method,
          FunctionNode(EmptyStatement()),
          fileUri: lib.fileUri,
        );
        cls.addProcedure(method);
        lib.addClass(cls);

        final comp = makeComponent(
          coreLib: makeDartCoreLibrary(),
          userLib: lib,
        );
        final projectScope = makeProjectScope();
        final policy = PolicyResolver().resolve(
          component: comp,
          config: RefractorConfig(
            passes: [RenamePassConfig(seed: seed)],
          ),
          projectScope: projectScope,
        );
        await RenamePass(
          config: RenamePassConfig(seed: seed),
          policy: policy.rename,
          projectScope: projectScope,
        ).run(comp);
        return method.name.text;
      }

      final name1 = await runWithSeed(42);
      final name2 = await runWithSeed(42);
      expect(name1, equals(name2));
    });

    test('reusing the same pass instance preserves seeded output', () async {
      Future<String> runWithSharedPass(RenamePass pass) async {
        final lib = makeUserLibrary();
        final cls = Class(name: 'Svc', fileUri: lib.fileUri);
        final method = Procedure(
          Name('process'),
          ProcedureKind.Method,
          FunctionNode(EmptyStatement()),
          fileUri: lib.fileUri,
        );
        cls.addProcedure(method);
        lib.addClass(cls);

        final comp = makeComponent(
          coreLib: makeDartCoreLibrary(),
          userLib: lib,
        );
        await pass.run(comp);
        return method.name.text;
      }

      final scope = makeProjectScope();
      final pass = RenamePass(
        config: const RenamePassConfig(seed: 42),
        policy: const RenamePolicyView(),
        projectScope: scope,
      );

      final firstName = await runWithSharedPass(pass);
      final secondName = await runWithSharedPass(pass);

      expect(firstName, equals(secondName));
    });

    test('name pool uses alphabetic names', () async {
      final cls = Class(name: 'MyClass', fileUri: userLib.fileUri);
      final method = Procedure(
        Name('myMethod'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      cls.addProcedure(method);
      userLib.addClass(cls);

      await runPass();

      expect(method.name.text, isNot(contains(r'$')));
      expect(method.name.text, matches(RegExp(r'^[a-zA-Z]+$')));
    });

    test('seed in config flows through to name generation', () async {
      final cls = Class(name: 'Svc', fileUri: userLib.fileUri);
      final method = Procedure(
        Name('run'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      cls.addProcedure(method);
      userLib.addClass(cls);

      await runPass(const RenamePassConfig(seed: 123));

      expect(method.name.text, isNot('run'));
      expect(method.name.text, matches(RegExp(r'^[a-zA-Z]+$')));
    });

    test('overloading is disabled by default for unrelated families', () async {
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

      await runPass();

      expect(
        left.procedures.single.name.text,
        isNot(equals(right.procedures.single.name.text)),
      );
    });

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

      final mapping = await runPass(const RenamePassConfig(overloading: true));

      expect(
        left.procedures.single.name.text,
        equals(right.procedures.single.name.text),
      );
      expect(mapping.symbolMap, isNotEmpty);
      expect(
        mapping.originalsFor(left.procedures.single.name.text).toList(),
        containsAll(['alpha', 'beta']),
      );
      expect(
        RenameArtifact(mapping: mapping).toJson()['symbol_map'],
        containsPair(
          left.procedures.single.name.text,
          containsAll(['alpha', 'beta']),
        ),
      );
    });

    test('overloading never pulls singleton members into slot reuse', () async {
      final topLevel = Procedure(
        Name('topLevel'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      final cls = Class(name: 'Svc', fileUri: userLib.fileUri)
        ..addProcedure(
          Procedure(
            Name('instanceWork'),
            ProcedureKind.Method,
            FunctionNode(EmptyStatement()),
            fileUri: userLib.fileUri,
          ),
        )
        ..addProcedure(
          Procedure(
            Name('helper'),
            ProcedureKind.Method,
            FunctionNode(EmptyStatement()),
            fileUri: userLib.fileUri,
            isStatic: true,
          ),
        );
      userLib
        ..addProcedure(topLevel)
        ..addClass(cls);

      await runPass(const RenamePassConfig(overloading: true));

      expect(topLevel.name.text, isNot(equals(cls.procedures.first.name.text)));
      expect(
        cls.procedures[1].name.text,
        isNot(equals(cls.procedures.first.name.text)),
      );
    });

    // --- TFA compatibility tests ---
    // These verify that renaming does not break AOT tree-shaking (TFA).
    // If a user class overrides an SDK/external method and we rename
    // the override, TFA can no longer trace the call → removes the body
    // → runtime crash: "code removed by Dart AOT compiler (TFA)".

    test('method overriding SDK supertype is NOT renamed', () async {
      // Simulate Object declaring toString().
      final objectClass =
          coreLib.classes.firstWhere(
            (c) => c.name == 'Object',
          )..addProcedure(
            Procedure(
              Name('toString'),
              ProcedureKind.Method,
              FunctionNode(EmptyStatement()),
              fileUri: coreLib.fileUri,
            ),
          );

      final cls = Class(
        name: 'MyService',
        fileUri: userLib.fileUri,
        supertype: objectClass.asThisSupertype,
      );
      final toStringOverride = Procedure(
        Name('toString'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      cls.addProcedure(toStringOverride);
      userLib.addClass(cls);

      await runPass();

      expect(
        toStringOverride.name.text,
        equals('toString'),
        reason: 'Renaming an SDK override breaks TFA traceability',
      );
      // The class itself can still be renamed.
      expect(cls.name, isNot('MyService'));
    });

    test(
      'method overriding external package interface is NOT renamed',
      () async {
        final extUri = Uri.parse('package:flutter/widgets.dart');
        final extLib = Library(extUri, fileUri: extUri);
        final widget = Class(name: 'StatelessWidget', fileUri: extUri)
          ..addProcedure(
            Procedure(
              Name('build'),
              ProcedureKind.Method,
              FunctionNode(EmptyStatement()),
              fileUri: extUri,
            ),
          );
        extLib.addClass(widget);

        final cls = Class(
          name: 'MyWidget',
          fileUri: userLib.fileUri,
          supertype: widget.asThisSupertype,
        );
        final buildOverride = Procedure(
          Name('build'),
          ProcedureKind.Method,
          FunctionNode(EmptyStatement()),
          fileUri: userLib.fileUri,
        );
        final userOnly = Procedure(
          Name('doWork'),
          ProcedureKind.Method,
          FunctionNode(EmptyStatement()),
          fileUri: userLib.fileUri,
        );
        cls
          ..addProcedure(buildOverride)
          ..addProcedure(userOnly);
        userLib.addClass(cls);

        component = Component(libraries: [coreLib, userLib, extLib])
          ..setMainMethodAndMode(null, true);
        await makePass(component).run(component);

        expect(
          buildOverride.name.text,
          equals('build'),
          reason: 'Renaming an external interface override breaks TFA',
        );
        expect(userOnly.name.text, isNot('doWork'));
      },
    );

    test('user-only method on class with SDK supertype IS renamed', () async {
      final objectClass = coreLib.classes.firstWhere(
        (c) => c.name == 'Object',
      );

      final cls = Class(
        name: 'MyService',
        fileUri: userLib.fileUri,
        supertype: objectClass.asThisSupertype,
      );
      final userMethod = Procedure(
        Name('processData'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      cls.addProcedure(userMethod);
      userLib.addClass(cls);

      await runPass();

      expect(
        userMethod.name.text,
        isNot('processData'),
        reason: 'User-only methods should still be renamed',
      );
    });

    test(
      'InstanceInvocation call site stays consistent after rename',
      () async {
        final cls = Class(name: 'Svc', fileUri: userLib.fileUri);
        final method = Procedure(
          Name('process'),
          ProcedureKind.Method,
          FunctionNode(EmptyStatement()),
          fileUri: userLib.fileUri,
        );
        cls.addProcedure(method);

        final receiver = VariableDeclaration('svc');
        final call = InstanceInvocation(
          InstanceAccessKind.Instance,
          VariableGet(receiver),
          Name('process'),
          Arguments.empty(),
          interfaceTarget: method,
          functionType: FunctionType(
            [],
            const VoidType(),
            Nullability.nonNullable,
          ),
        );
        final caller = Procedure(
          Name('main'),
          ProcedureKind.Method,
          FunctionNode(ExpressionStatement(call)),
          fileUri: userLib.fileUri,
        );
        userLib
          ..addClass(cls)
          ..addProcedure(caller);

        await runPass();

        // Call site name must match the renamed method — otherwise TFA
        // cannot trace the call and may remove the method body.
        expect(call.name.text, equals(method.name.text));
        expect(call.interfaceTarget, same(method));
        expect(method.name.text, isNot('process'));
      },
    );

    test(
      'DynamicInvocation stays consistent when unrelated members share a name',
      () async {
        final firstClass = Class(name: 'First', fileUri: userLib.fileUri);
        final firstMethod = Procedure(
          Name('foo'),
          ProcedureKind.Method,
          FunctionNode(EmptyStatement()),
          fileUri: userLib.fileUri,
        );
        firstClass.addProcedure(firstMethod);

        final secondClass = Class(name: 'Second', fileUri: userLib.fileUri);
        final secondMethod = Procedure(
          Name('foo'),
          ProcedureKind.Method,
          FunctionNode(EmptyStatement()),
          fileUri: userLib.fileUri,
        );
        secondClass.addProcedure(secondMethod);

        final receiver = VariableDeclaration('value');
        final call = DynamicInvocation(
          DynamicAccessKind.Dynamic,
          VariableGet(receiver),
          Name('foo'),
          Arguments.empty(),
        );
        final caller = Procedure(
          Name('main'),
          ProcedureKind.Method,
          FunctionNode(
            ExpressionStatement(call),
            positionalParameters: [receiver],
            requiredParameterCount: 1,
          ),
          fileUri: userLib.fileUri,
        );
        userLib
          ..addClass(firstClass)
          ..addClass(secondClass)
          ..addProcedure(caller);

        await runPass();

        expect(firstMethod.name.text, equals(secondMethod.name.text));
        expect(call.name.text, equals(firstMethod.name.text));
        expect(call.name.text, isNot('foo'));
      },
    );

    test(
      'DynamicInvocation keeps named parameters stable on instance methods',
      () async {
        final namedParam = VariableDeclaration('debug');
        final cls = Class(name: 'Svc', fileUri: userLib.fileUri);
        final method = Procedure(
          Name('configure'),
          ProcedureKind.Method,
          FunctionNode(
            EmptyStatement(),
            namedParameters: [namedParam],
          ),
          fileUri: userLib.fileUri,
        );
        cls.addProcedure(method);

        final receiver = VariableDeclaration('value');
        final call = DynamicInvocation(
          DynamicAccessKind.Dynamic,
          VariableGet(receiver),
          Name('configure'),
          Arguments(
            [],
            named: [NamedExpression('debug', BoolLiteral(true))],
          ),
        );
        final caller = Procedure(
          Name('main'),
          ProcedureKind.Method,
          FunctionNode(
            ExpressionStatement(call),
            positionalParameters: [receiver],
            requiredParameterCount: 1,
          ),
          fileUri: userLib.fileUri,
        );
        userLib
          ..addClass(cls)
          ..addProcedure(caller);

        await runPass();

        expect(method.name.text, isNot('configure'));
        expect(call.name.text, equals(method.name.text));
        expect(namedParam.name, 'debug');
        expect(call.arguments.named.single.name, 'debug');
      },
    );

    test(
      'DynamicInvocation stays unchanged when same selector is '
      'excluded elsewhere',
      () async {
        final firstClass = Class(name: 'First', fileUri: userLib.fileUri);
        final keptMethod = Procedure(
          Name('foo'),
          ProcedureKind.Method,
          FunctionNode(EmptyStatement()),
          fileUri: userLib.fileUri,
        )..addAnnotation(makeRefractorKeepAnnotation(annotationLib));
        firstClass.addProcedure(keptMethod);

        final secondClass = Class(name: 'Second', fileUri: userLib.fileUri);
        final renamedMethod = Procedure(
          Name('foo'),
          ProcedureKind.Method,
          FunctionNode(EmptyStatement()),
          fileUri: userLib.fileUri,
        );
        secondClass.addProcedure(renamedMethod);

        final receiver = VariableDeclaration('value');
        final call = DynamicInvocation(
          DynamicAccessKind.Dynamic,
          VariableGet(receiver),
          Name('foo'),
          Arguments.empty(),
        );
        final caller = Procedure(
          Name('main'),
          ProcedureKind.Method,
          FunctionNode(
            ExpressionStatement(call),
            positionalParameters: [receiver],
            requiredParameterCount: 1,
          ),
          fileUri: userLib.fileUri,
        );
        userLib
          ..addClass(firstClass)
          ..addClass(secondClass)
          ..addProcedure(caller);

        await runPass();

        expect(keptMethod.name.text, 'foo');
        expect(renamedMethod.name.text, 'foo');
        expect(call.name.text, 'foo');
      },
    );

    test('generic pragma annotation no longer prevents rename', () async {
      final pragmaClass = Class(name: 'pragma', fileUri: coreLib.fileUri);
      coreLib.addClass(pragmaClass);

      final cls = Class(name: 'KeepMe', fileUri: userLib.fileUri)
        ..addAnnotation(
          ConstantExpression(
            InstanceConstant(pragmaClass.reference, const [], const {}),
          ),
        );
      userLib.addClass(cls);

      await runPass();

      expect(cls.name, isNot('KeepMe'));
    });

    test(
      'DynamicInvocation stays unchanged when selector exists in '
      'excluded library',
      () async {
        final otherUri = Uri.parse('package:other_pkg/other.dart');
        final otherLib = Library(otherUri, fileUri: otherUri);
        final externalClass = Class(name: 'External', fileUri: otherUri);
        final externalMethod = Procedure(
          Name('foo'),
          ProcedureKind.Method,
          FunctionNode(EmptyStatement()),
          fileUri: otherUri,
        );
        externalClass.addProcedure(externalMethod);
        otherLib.addClass(externalClass);

        final localClass = Class(name: 'Local', fileUri: userLib.fileUri);
        final localMethod = Procedure(
          Name('foo'),
          ProcedureKind.Method,
          FunctionNode(EmptyStatement()),
          fileUri: userLib.fileUri,
        );
        localClass.addProcedure(localMethod);
        userLib.addClass(localClass);

        final receiver = VariableDeclaration('value');
        final call = DynamicInvocation(
          DynamicAccessKind.Dynamic,
          VariableGet(receiver),
          Name('foo'),
          Arguments.empty(),
        );
        final caller = Procedure(
          Name('main'),
          ProcedureKind.Method,
          FunctionNode(
            ExpressionStatement(call),
            positionalParameters: [receiver],
            requiredParameterCount: 1,
          ),
          fileUri: userLib.fileUri,
        );
        userLib.addProcedure(caller);

        component = Component(libraries: [coreLib, userLib, otherLib])
          ..setMainMethodAndMode(null, true);
        final result = await makePass(component).run(component);

        expect(result, isA<PassSucceeded>());
        expect(externalMethod.name.text, 'foo');
        expect(localMethod.name.text, 'foo');
        expect(call.name.text, 'foo');
      },
    );

    test(
      'selector shared with excluded library still renames when no dynamic use',
      () async {
        final otherUri = Uri.parse('package:other_pkg/other.dart');
        final otherLib = Library(otherUri, fileUri: otherUri);
        final externalClass = Class(name: 'External', fileUri: otherUri)
          ..addProcedure(
            Procedure(
              Name('map'),
              ProcedureKind.Method,
              FunctionNode(EmptyStatement()),
              fileUri: otherUri,
            ),
          );
        otherLib.addClass(externalClass);

        final localClass = Class(name: 'Local', fileUri: userLib.fileUri);
        final localMethod = Procedure(
          Name('map'),
          ProcedureKind.Method,
          FunctionNode(EmptyStatement()),
          fileUri: userLib.fileUri,
        );
        localClass.addProcedure(localMethod);
        userLib.addClass(localClass);

        component = Component(libraries: [coreLib, userLib, otherLib])
          ..setMainMethodAndMode(null, true);
        final result = await makePass(component).run(component);

        expect(result, isA<PassSucceeded>());
        expect(localMethod.name.text, isNot('map'));
      },
    );

    test(
      'FunctionInvocation through variable tear-off preserves callable '
      'surface',
      () async {
        final namedParam = VariableDeclaration('debug');
        final callee = Procedure(
          Name('configure'),
          ProcedureKind.Method,
          FunctionNode(
            EmptyStatement(),
            namedParameters: [namedParam],
          ),
          fileUri: userLib.fileUri,
          isStatic: true,
        );
        userLib.addProcedure(callee);

        final tearOff = VariableDeclaration(
          'callback',
          initializer: StaticTearOff(callee),
          isFinal: true,
        );
        final call = FunctionInvocation(
          FunctionAccessKind.FunctionType,
          VariableGet(tearOff),
          Arguments(
            [],
            named: [
              NamedExpression('debug', BoolLiteral(true)),
            ],
          ),
          functionType: null,
        );
        final caller = Procedure(
          Name('main'),
          ProcedureKind.Method,
          FunctionNode(
            Block([
              tearOff,
              ExpressionStatement(call),
            ]),
          ),
          fileUri: userLib.fileUri,
        );
        userLib.addProcedure(caller);

        await runPass();

        expect(callee.name.text, equals('configure'));
        expect(namedParam.name, equals('debug'));
        expect(call.arguments.named.single.name, equals('debug'));
      },
    );

    test(
      'FunctionInvocation through mutable variable alias keeps '
      'original named argument',
      () async {
        final namedParam = VariableDeclaration('debug');
        final callee = Procedure(
          Name('configure'),
          ProcedureKind.Method,
          FunctionNode(
            EmptyStatement(),
            namedParameters: [namedParam],
          ),
          fileUri: userLib.fileUri,
          isStatic: true,
        );
        userLib.addProcedure(callee);

        final tearOff = VariableDeclaration(
          'callback',
          initializer: StaticTearOff(callee),
        );
        final call = FunctionInvocation(
          FunctionAccessKind.FunctionType,
          VariableGet(tearOff),
          Arguments(
            [],
            named: [
              NamedExpression('debug', BoolLiteral(true)),
            ],
          ),
          functionType: null,
        );
        final caller = Procedure(
          Name('main'),
          ProcedureKind.Method,
          FunctionNode(
            Block([
              tearOff,
              ExpressionStatement(call),
            ]),
          ),
          fileUri: userLib.fileUri,
        );
        userLib.addProcedure(caller);

        await runPass();

        expect(callee.name.text, equals('configure'));
        expect(namedParam.name, equals('debug'));
        expect(call.arguments.named.single.name, 'debug');
      },
    );

    test(
      'FunctionInvocation through mutable static field alias keeps '
      'original named argument',
      () async {
        final namedParam = VariableDeclaration('debug');
        final callee = Procedure(
          Name('configure'),
          ProcedureKind.Method,
          FunctionNode(
            EmptyStatement(),
            namedParameters: [namedParam],
          ),
          fileUri: userLib.fileUri,
          isStatic: true,
        );
        userLib.addProcedure(callee);

        final callbackField = Field.mutable(
          Name('callback'),
          initializer: StaticTearOff(callee),
          fileUri: userLib.fileUri,
          isStatic: true,
        );
        userLib.addField(callbackField);

        final call = FunctionInvocation(
          FunctionAccessKind.FunctionType,
          StaticGet(callbackField),
          Arguments(
            [],
            named: [
              NamedExpression('debug', BoolLiteral(true)),
            ],
          ),
          functionType: null,
        );
        final caller = Procedure(
          Name('main'),
          ProcedureKind.Method,
          FunctionNode(ExpressionStatement(call)),
          fileUri: userLib.fileUri,
        );
        userLib.addProcedure(caller);

        await runPass();

        expect(callee.name.text, equals('configure'));
        expect(namedParam.name, equals('debug'));
        expect(call.arguments.named.single.name, 'debug');
      },
    );

    test(
      'FunctionInvocation through final constructor tear-off preserves '
      'callable surface',
      () async {
        final namedParam = VariableDeclaration('debug');
        final cls = Class(name: 'Widget', fileUri: userLib.fileUri);
        final constructor = Constructor(
          FunctionNode(
            EmptyStatement(),
            namedParameters: [namedParam],
          ),
          name: Name('create'),
          fileUri: userLib.fileUri,
        );
        cls.addConstructor(constructor);
        userLib.addClass(cls);

        final tearOff = VariableDeclaration(
          'factory',
          initializer: ConstructorTearOff(constructor),
          isFinal: true,
        );
        final call = FunctionInvocation(
          FunctionAccessKind.FunctionType,
          VariableGet(tearOff),
          Arguments(
            [],
            named: [
              NamedExpression('debug', BoolLiteral(true)),
            ],
          ),
          functionType: null,
        );
        final caller = Procedure(
          Name('main'),
          ProcedureKind.Method,
          FunctionNode(
            Block([
              tearOff,
              ExpressionStatement(call),
            ]),
          ),
          fileUri: userLib.fileUri,
        );
        userLib.addProcedure(caller);

        await runPass();

        expect(constructor.name.text, equals('create'));
        expect(namedParam.name, equals('debug'));
        expect(call.arguments.named.single.name, equals('debug'));
      },
    );

    test(
      'FunctionInvocation through final redirecting factory tear-off preserves '
      'callable surface',
      () async {
        final namedParam = VariableDeclaration('debug');
        final cls = Class(name: 'Widget', fileUri: userLib.fileUri);
        final targetConstructor = Constructor(
          FunctionNode(EmptyStatement()),
          name: Name('create'),
          fileUri: userLib.fileUri,
        );
        final redirectingFactory = Procedure(
          Name('factory'),
          ProcedureKind.Factory,
          FunctionNode(
              EmptyStatement(),
              namedParameters: [namedParam],
            )
            ..redirectingFactoryTarget = RedirectingFactoryTarget(
              targetConstructor,
              const <DartType>[],
            ),
          fileUri: userLib.fileUri,
          isStatic: true,
        );
        cls
          ..addConstructor(targetConstructor)
          ..addProcedure(redirectingFactory);
        userLib.addClass(cls);

        final tearOff = VariableDeclaration(
          'factory',
          initializer: RedirectingFactoryTearOff(redirectingFactory),
          isFinal: true,
        );
        final call = FunctionInvocation(
          FunctionAccessKind.FunctionType,
          VariableGet(tearOff),
          Arguments(
            [],
            named: [
              NamedExpression('debug', BoolLiteral(true)),
            ],
          ),
          functionType: null,
        );
        final caller = Procedure(
          Name('main'),
          ProcedureKind.Method,
          FunctionNode(
            Block([
              tearOff,
              ExpressionStatement(call),
            ]),
          ),
          fileUri: userLib.fileUri,
        );
        userLib.addProcedure(caller);

        await runPass();

        expect(redirectingFactory.name.text, equals('factory'));
        expect(namedParam.name, equals('debug'));
        expect(call.arguments.named.single.name, equals('debug'));
      },
    );

    test(
      'FunctionInvocation through instantiated generic tear-off preserves '
      'callable surface',
      () async {
        final namedParam = VariableDeclaration('debug');
        final typeParameter = TypeParameter('T');
        final intClass = coreLib.classes.firstWhere((c) => c.name == 'int');
        final genericHelper = Procedure(
          Name('helper'),
          ProcedureKind.Method,
          FunctionNode(
            EmptyStatement(),
            typeParameters: [typeParameter],
            namedParameters: [namedParam],
          ),
          fileUri: userLib.fileUri,
          isStatic: true,
        );
        userLib.addProcedure(genericHelper);

        final tearOff = VariableDeclaration(
          'callback',
          initializer: Instantiation(
            StaticTearOff(genericHelper),
            [
              InterfaceType(intClass, Nullability.nonNullable),
            ],
          ),
          isFinal: true,
        );
        final call = FunctionInvocation(
          FunctionAccessKind.FunctionType,
          VariableGet(tearOff),
          Arguments(
            [],
            named: [
              NamedExpression('debug', BoolLiteral(true)),
            ],
          ),
          functionType: null,
        );
        final caller = Procedure(
          Name('main'),
          ProcedureKind.Method,
          FunctionNode(
            Block([
              tearOff,
              ExpressionStatement(call),
            ]),
          ),
          fileUri: userLib.fileUri,
        );
        userLib.addProcedure(caller);

        await runPass();

        expect(genericHelper.name.text, equals('helper'));
        expect(namedParam.name, equals('debug'));
        expect(call.arguments.named.single.name, equals('debug'));
      },
    );

    test(
      'FunctionInvocation through cyclic final static aliases keeps '
      'original named argument',
      () async {
        final namedParam = VariableDeclaration('debug');
        final callee = Procedure(
          Name('configure'),
          ProcedureKind.Method,
          FunctionNode(
            EmptyStatement(),
            namedParameters: [namedParam],
          ),
          fileUri: userLib.fileUri,
          isStatic: true,
        );
        userLib.addProcedure(callee);

        final firstAlias = Field.mutable(
          Name('first'),
          initializer: NullLiteral(),
          fileUri: userLib.fileUri,
          isStatic: true,
        )..isFinal = true;
        final secondAlias = Field.mutable(
          Name('second'),
          initializer: StaticGet(firstAlias),
          fileUri: userLib.fileUri,
          isStatic: true,
        )..isFinal = true;
        firstAlias.initializer = StaticGet(secondAlias);
        userLib
          ..addField(firstAlias)
          ..addField(secondAlias);

        final call = FunctionInvocation(
          FunctionAccessKind.FunctionType,
          StaticGet(firstAlias),
          Arguments(
            [],
            named: [
              NamedExpression('debug', BoolLiteral(true)),
            ],
          ),
          functionType: null,
        );
        final caller = Procedure(
          Name('main'),
          ProcedureKind.Method,
          FunctionNode(ExpressionStatement(call)),
          fileUri: userLib.fileUri,
        );
        userLib.addProcedure(caller);

        await runPass();

        expect(callee.name.text, isNot('configure'));
        expect(namedParam.name, isNot('debug'));
        expect(call.arguments.named.single.name, 'debug');
      },
    );

    test(
      'FunctionInvocation through instantiated redirecting factory tear-off '
      'preserves callable surface',
      () async {
        final namedParam = VariableDeclaration('debug');
        final typeParameter = TypeParameter('T');
        final intClass = coreLib.classes.firstWhere((c) => c.name == 'int');
        final cls = Class(name: 'Widget', fileUri: userLib.fileUri);
        final targetConstructor = Constructor(
          FunctionNode(EmptyStatement()),
          name: Name('create'),
          fileUri: userLib.fileUri,
        );
        final redirectingFactory = Procedure(
          Name('factory'),
          ProcedureKind.Factory,
          FunctionNode(
              EmptyStatement(),
              typeParameters: [typeParameter],
              namedParameters: [namedParam],
            )
            ..redirectingFactoryTarget = RedirectingFactoryTarget(
              targetConstructor,
              const <DartType>[],
            ),
          fileUri: userLib.fileUri,
          isStatic: true,
        );
        cls
          ..addConstructor(targetConstructor)
          ..addProcedure(redirectingFactory);
        userLib.addClass(cls);

        final tearOff = VariableDeclaration(
          'factory',
          initializer: Instantiation(
            RedirectingFactoryTearOff(redirectingFactory),
            [
              InterfaceType(intClass, Nullability.nonNullable),
            ],
          ),
          isFinal: true,
        );
        final call = FunctionInvocation(
          FunctionAccessKind.FunctionType,
          VariableGet(tearOff),
          Arguments(
            [],
            named: [
              NamedExpression('debug', BoolLiteral(true)),
            ],
          ),
          functionType: null,
        );
        final caller = Procedure(
          Name('main'),
          ProcedureKind.Method,
          FunctionNode(
            Block([
              tearOff,
              ExpressionStatement(call),
            ]),
          ),
          fileUri: userLib.fileUri,
        );
        userLib.addProcedure(caller);

        await runPass();

        expect(redirectingFactory.name.text, equals('factory'));
        expect(namedParam.name, equals('debug'));
        expect(call.arguments.named.single.name, equals('debug'));
      },
    );

    test(
      'InstanceTearOff preserves callable surface for instance methods',
      () async {
        final namedParam = VariableDeclaration('debug');
        final cls = Class(name: 'Widget', fileUri: userLib.fileUri);
        final method = Procedure(
          Name('configure'),
          ProcedureKind.Method,
          FunctionNode(
            EmptyStatement(),
            namedParameters: [namedParam],
          ),
          fileUri: userLib.fileUri,
        );
        cls.addProcedure(method);
        userLib.addClass(cls);

        final receiver = VariableDeclaration('widget');
        final tearOff = VariableDeclaration(
          'callback',
          initializer: InstanceTearOff(
            InstanceAccessKind.Instance,
            VariableGet(receiver),
            Name('configure'),
            resultType: const DynamicType(),
            interfaceTarget: method,
          ),
          isFinal: true,
        );
        final call = FunctionInvocation(
          FunctionAccessKind.FunctionType,
          VariableGet(tearOff),
          Arguments(
            [],
            named: [NamedExpression('debug', BoolLiteral(true))],
          ),
          functionType: null,
        );
        final caller = Procedure(
          Name('main'),
          ProcedureKind.Method,
          FunctionNode(
            Block([
              receiver,
              tearOff,
              ExpressionStatement(call),
            ]),
          ),
          fileUri: userLib.fileUri,
        );
        userLib.addProcedure(caller);

        await runPass();

        expect(method.name.text, equals('configure'));
        expect(namedParam.name, equals('debug'));
        expect(call.arguments.named.single.name, equals('debug'));
      },
    );

    test('static members are NOT in override families', () async {
      final baseClass = Class(name: 'Base', fileUri: userLib.fileUri);
      final staticMethod = Procedure(
        Name('helper'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
        isStatic: true,
      );
      baseClass.addProcedure(staticMethod);
      userLib.addClass(baseClass);

      final derivedClass = Class(
        name: 'Derived',
        fileUri: userLib.fileUri,
        supertype: baseClass.asThisSupertype,
      );
      final instanceMethod = Procedure(
        Name('helper'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      derivedClass.addProcedure(instanceMethod);
      userLib.addClass(derivedClass);

      await runPass();

      expect(staticMethod.name.text, isNot('helper'));
      expect(instanceMethod.name.text, isNot('helper'));
    });
  });
}
