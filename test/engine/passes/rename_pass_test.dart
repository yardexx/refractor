import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/passes/rename/rename_pass.dart';
import 'package:refractor/src/engine/runner/pass_options.dart';
import 'package:test/test.dart';

import '../../helpers/kernel_helpers.dart';

void main() {
  group('RenamePass', () {
    late Library coreLib;
    late Library userLib;
    late Component component;

    setUp(() {
      coreLib = makeDartCoreLibrary();
      userLib = makeUserLibrary();
    });

    void runPass(PassOptions options) {
      final context = makePassContext(options);
      component = makeComponent(coreLib: coreLib, userLib: userLib);
      RenamePass().run(component, context);
    }

    test('renames class name in user library', () {
      final cls = Class(name: 'MyService', fileUri: userLib.fileUri);
      userLib.addClass(cls);

      final context = makePassContext();
      component = makeComponent(coreLib: coreLib, userLib: userLib);
      RenamePass().run(component, context);

      expect(cls.name, isNot('MyService'));
    });

    test('renames procedure name in user library', () {
      final proc = Procedure(
        Name('doWork'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(proc);

      final context = makePassContext(
        const PassOptions(preserveMain: false),
      );
      component = makeComponent(coreLib: coreLib, userLib: userLib);
      RenamePass().run(component, context);

      expect(proc.name.text, isNot('doWork'));
    });

    test('renames field name in user library', () {
      final cls = Class(name: 'Svc', fileUri: userLib.fileUri);
      final field = Field.mutable(
        Name('_secret', userLib),
        fileUri: userLib.fileUri,
      );
      cls.addField(field);
      userLib.addClass(cls);

      final context = makePassContext();
      component = makeComponent(coreLib: coreLib, userLib: userLib);
      RenamePass().run(component, context);

      expect(field.name.text, isNot('_secret'));
      expect(field.name.text, startsWith('_'));
    });

    test('skips dart: libraries entirely', () {
      final coreClass = coreLib.classes.firstWhere((c) => c.name == 'int');

      final context = makePassContext();
      component = makeComponent(coreLib: coreLib, userLib: userLib);
      RenamePass().run(component, context);

      expect(coreClass.name, equals('int'));
    });

    test('skips non-project package: libraries', () {
      final otherUri = Uri.parse('package:other_pkg/other.dart');
      final otherLib = Library(otherUri, fileUri: otherUri);
      final cls = Class(name: 'ExternalClass', fileUri: otherUri);
      otherLib.addClass(cls);

      final context = makePassContext();
      component = Component(libraries: [coreLib, userLib, otherLib])
        ..setMainMethodAndMode(null, true);
      RenamePass().run(component, context);

      expect(cls.name, equals('ExternalClass'));
    });

    test('preserveMain: true keeps main procedure unchanged', () {
      final mainProc = Procedure(
        Name('main'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(mainProc);

      runPass(const PassOptions());

      expect(mainProc.name.text, equals('main'));
    });

    test('preserveMain: false renames main', () {
      final mainProc = Procedure(
        Name('main'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(mainProc);

      runPass(const PassOptions(preserveMain: false));

      expect(mainProc.name.text, isNot('main'));
    });

    test('@pragma annotation prevents rename of annotated node', () {
      final pragmaClass = Class(name: 'pragma', fileUri: coreLib.fileUri);
      coreLib.addClass(pragmaClass);

      final cls = Class(name: 'KeepMe', fileUri: userLib.fileUri)
        ..addAnnotation(
          ConstantExpression(
            InstanceConstant(
              pragmaClass.reference,
              [],
              {},
            ),
          ),
        );
      userLib.addClass(cls);

      final context = makePassContext();
      component = makeComponent(coreLib: coreLib, userLib: userLib);
      RenamePass().run(component, context);

      expect(cls.name, equals('KeepMe'));
    });

    test('field and getter with same name get same obfuscated name', () {
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

      final context = makePassContext();
      component = makeComponent(coreLib: coreLib, userLib: userLib);
      RenamePass().run(component, context);

      expect(field.name.text, equals(getter.name.text));
    });

    test('InstanceGet.name is updated when interfaceTarget is renamed', () {
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

      final context = makePassContext();
      component = makeComponent(coreLib: coreLib, userLib: userLib);
      RenamePass().run(component, context);

      expect(instanceGet.name.text, equals(field.name.text));
      expect(instanceGet.name.text, isNot('data'));
    });

    test('SymbolTable records original to obfuscated mappings', () {
      final cls = Class(name: 'Tracker', fileUri: userLib.fileUri);
      userLib.addClass(cls);

      final context = makePassContext();
      component = makeComponent(coreLib: coreLib, userLib: userLib);
      RenamePass().run(component, context);

      expect(context.symbolTable.size, greaterThan(0));
      expect(context.symbolTable.obfuscated('Tracker'), equals(cls.name));
    });

    test('renames named constructor', () {
      final cls = Class(name: 'MyClass', fileUri: userLib.fileUri);
      final ctor = Constructor(
        FunctionNode(EmptyStatement()),
        name: Name('create'),
        fileUri: userLib.fileUri,
      );
      cls.addConstructor(ctor);
      userLib.addClass(cls);

      final context = makePassContext();
      component = makeComponent(coreLib: coreLib, userLib: userLib);
      RenamePass().run(component, context);

      expect(ctor.name.text, isNot('create'));
    });

    test('does not rename default (unnamed) constructor', () {
      final cls = Class(name: 'MyClass', fileUri: userLib.fileUri);
      final ctor = Constructor(
        FunctionNode(EmptyStatement()),
        name: Name(''),
        fileUri: userLib.fileUri,
      );
      cls.addConstructor(ctor);
      userLib.addClass(cls);

      final context = makePassContext();
      component = makeComponent(coreLib: coreLib, userLib: userLib);
      RenamePass().run(component, context);

      expect(ctor.name.text, equals(''));
    });

    test('constructor with @pragma is not renamed', () {
      final pragmaClass = Class(name: 'pragma', fileUri: coreLib.fileUri);
      coreLib.addClass(pragmaClass);

      final cls = Class(name: 'MyClass', fileUri: userLib.fileUri);
      final ctor =
          Constructor(
            FunctionNode(EmptyStatement()),
            name: Name('kept'),
            fileUri: userLib.fileUri,
          )..addAnnotation(
            ConstantExpression(
              InstanceConstant(pragmaClass.reference, [], {}),
            ),
          );
      cls.addConstructor(ctor);
      userLib.addClass(cls);

      final context = makePassContext();
      component = makeComponent(coreLib: coreLib, userLib: userLib);
      RenamePass().run(component, context);

      expect(ctor.name.text, equals('kept'));
    });

    test('StaticInvocation still resolves after procedure rename', () {
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

      final context = makePassContext(
        const PassOptions(preserveMain: false),
      );
      component = makeComponent(coreLib: coreLib, userLib: userLib);
      RenamePass().run(component, context);

      expect(proc.name.text, isNot('compute'));
      expect(invocation.target, same(proc));
    });

    test('StaticGet still resolves after field rename', () {
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

      final context = makePassContext(
        const PassOptions(preserveMain: false),
      );
      component = makeComponent(coreLib: coreLib, userLib: userLib);
      RenamePass().run(component, context);

      expect(field.name.text, isNot('config'));
      expect(staticGet.target, same(field));
    });

    test('ConstructorInvocation still resolves after constructor rename', () {
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

      final context = makePassContext(
        const PassOptions(preserveMain: false),
      );
      component = makeComponent(coreLib: coreLib, userLib: userLib);
      RenamePass().run(component, context);

      expect(ctor.name.text, isNot('build'));
      expect(invocation.target, same(ctor));
    });

    test('SuperInitializer still resolves after constructor rename', () {
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

      final context = makePassContext();
      component = makeComponent(coreLib: coreLib, userLib: userLib);
      RenamePass().run(component, context);

      expect(baseCtor.name.text, isNot('named'));
      expect(superInit.target, same(baseCtor));
    });

    test('RedirectingInitializer still resolves after constructor rename', () {
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

      final context = makePassContext();
      component = makeComponent(coreLib: coreLib, userLib: userLib);
      RenamePass().run(component, context);

      expect(primaryCtor.name.text, isNot('primary'));
      expect(redirect.target, same(primaryCtor));
    });

    test('StaticSet still resolves after field rename', () {
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

      final context = makePassContext(
        const PassOptions(preserveMain: false),
      );
      component = makeComponent(coreLib: coreLib, userLib: userLib);
      RenamePass().run(component, context);

      expect(field.name.text, isNot('setting'));
      expect(staticSet.target, same(field));
    });

    test('round-trip serialization succeeds after constructor rename', () {
      final cls = Class(name: 'Service', fileUri: userLib.fileUri);
      final ctor = Constructor(
        FunctionNode(EmptyStatement()),
        name: Name('create'),
        fileUri: userLib.fileUri,
      );
      cls.addConstructor(ctor);
      userLib.addClass(cls);

      final context = makePassContext();
      component = makeComponent(coreLib: coreLib, userLib: userLib);
      RenamePass().run(component, context);

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
    });

    test('renames local variables and parameters', () {
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

      final context = makePassContext();
      component = makeComponent(coreLib: coreLib, userLib: userLib);
      RenamePass().run(component, context);

      expect(local.name, isNot('localValue'));
      expect(param.name, isNot('count'));
    });

    // --- Tier 1 tests ---

    test('members of base and derived class get the SAME obfuscated name', () {
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

      final context = makePassContext();
      component = makeComponent(coreLib: coreLib, userLib: userLib);
      RenamePass().run(component, context);

      expect(baseMethod.name.text, equals(derivedMethod.name.text));
      expect(baseMethod.name.text, isNot('speak'));
    });

    test('members of two unrelated classes get the SAME obfuscated name '
        '(overloading)', () {
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

      final context = makePassContext();
      component = makeComponent(coreLib: coreLib, userLib: userLib);
      RenamePass().run(component, context);

      // Unrelated families can share the same name.
      expect(methodA.name.text, equals(methodB.name.text));
    });

    test('fixed seed produces stable output across two runs', () {
      String runWithSeed(int seed) {
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

        final ctx = makePassContext(const PassOptions(), seed);
        final comp = makeComponent(
          coreLib: makeDartCoreLibrary(),
          userLib: lib,
        );
        RenamePass().run(comp, ctx);
        return method.name.text;
      }

      final name1 = runWithSeed(42);
      final name2 = runWithSeed(42);
      expect(name1, equals(name2));
    });

    test('name pool uses alphabetic names', () {
      final cls = Class(name: 'MyClass', fileUri: userLib.fileUri);
      final method = Procedure(
        Name('myMethod'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      cls.addProcedure(method);
      userLib.addClass(cls);

      final context = makePassContext();
      component = makeComponent(coreLib: coreLib, userLib: userLib);
      RenamePass().run(component, context);

      // Should be alphabetic, not _$N format.
      expect(method.name.text, isNot(contains(r'$')));
      expect(method.name.text, matches(RegExp(r'^[a-zA-Z]+$')));
    });

    test('seed in config flows through to name generation', () {
      final cls = Class(name: 'Svc', fileUri: userLib.fileUri);
      final method = Procedure(
        Name('run'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      cls.addProcedure(method);
      userLib.addClass(cls);

      final context = makePassContext(const PassOptions(seed: 123), 123);
      component = makeComponent(coreLib: coreLib, userLib: userLib);
      RenamePass().run(component, context);

      // Just verify it produces a valid name with the seed.
      expect(method.name.text, isNot('run'));
      expect(method.name.text, matches(RegExp(r'^[a-zA-Z]+$')));
    });

    test('static members are NOT in override families', () {
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

      final context = makePassContext();
      component = makeComponent(coreLib: coreLib, userLib: userLib);
      RenamePass().run(component, context);

      // Static and instance methods with same name should be renamed
      // independently (they may or may not get the same name by coincidence,
      // but they should both be renamed).
      expect(staticMethod.name.text, isNot('helper'));
      expect(instanceMethod.name.text, isNot('helper'));
    });
  });
}
