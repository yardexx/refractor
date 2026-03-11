import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/passes/rename/declaration_collector.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_pass_options.dart';
import 'package:refractor/src/engine/passes/rename/override_family/class_relation_index.dart';
import 'package:refractor/src/engine/passes/rename/override_family/override_families.dart';
import 'package:refractor/src/engine/passes/rename/override_family/override_family_analyzer.dart';
import 'package:refractor/src/engine/runner/obfuscation_target.dart';
import 'package:test/test.dart';

import '../../../helpers/kernel_helpers.dart';

void main() {
  group('OverrideFamilyAnalyzer', () {
    late Library coreLib;
    late Library userLib;
    late OverrideFamilyAnalyzer analyzer;
    late ObfuscationTarget target;

    setUp(() {
      coreLib = makeDartCoreLibrary();
      userLib = makeUserLibrary();
      analyzer = OverrideFamilyAnalyzer();
      target = makeObfuscationTarget();
    });

    OverrideFamilies runAnalysis({
      List<Library>? libraries,
      RenamePassOptions options = const RenamePassOptions(),
    }) {
      final component = Component(
        libraries: libraries ?? [coreLib, userLib],
      )..setMainMethodAndMode(null, true);
      final declarations = DeclarationCollector(target, options)
        ..collect(component);
      final hierarchy = ClassRelationIndex.build(
        declarations.classScopes.map((c) => c.node),
      );
      return analyzer.analyze(declarations.classScopes, hierarchy);
    }

    test('base + derived: same-name methods in same family', () {
      final baseClass = Class(name: 'A', fileUri: userLib.fileUri);
      final baseMethod = Procedure(
        Name('foo'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      baseClass.addProcedure(baseMethod);
      userLib.addClass(baseClass);

      final derivedClass = Class(
        name: 'B',
        fileUri: userLib.fileUri,
        supertype: baseClass.asThisSupertype,
      );
      final derivedMethod = Procedure(
        Name('foo'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      derivedClass.addProcedure(derivedMethod);
      userLib.addClass(derivedClass);

      final analysis = runAnalysis();

      expect(analysis.familyOf[baseMethod], isNotNull);
      expect(
        analysis.familyOf[baseMethod],
        same(analysis.familyOf[derivedMethod]),
      );
    });

    test('interface: implementor in same family', () {
      final iface = Class(name: 'I', fileUri: userLib.fileUri);
      final ifaceMethod = Procedure(
        Name('bar'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      iface.addProcedure(ifaceMethod);
      userLib.addClass(iface);

      final impl = Class(
        name: 'C',
        fileUri: userLib.fileUri,
        implementedTypes: [iface.asThisSupertype],
      );
      final implMethod = Procedure(
        Name('bar'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      impl.addProcedure(implMethod);
      userLib.addClass(impl);

      final analysis = runAnalysis();

      expect(
        analysis.familyOf[ifaceMethod],
        same(analysis.familyOf[implMethod]),
      );
    });

    test('mixin: mixin member in same family as user', () {
      final mixin = Class(name: 'M', fileUri: userLib.fileUri);
      final mixinMethod = Procedure(
        Name('baz'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      mixin.addProcedure(mixinMethod);
      userLib.addClass(mixin);

      final user = Class(
        name: 'D',
        fileUri: userLib.fileUri,
        mixedInType: mixin.asThisSupertype,
      );
      final userMethod = Procedure(
        Name('baz'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      user.addProcedure(userMethod);
      userLib.addClass(user);

      final analysis = runAnalysis();

      expect(
        analysis.familyOf[mixinMethod],
        same(analysis.familyOf[userMethod]),
      );
    });

    test('unrelated classes: same-name methods in different families', () {
      final classA = Class(name: 'A', fileUri: userLib.fileUri);
      final methodA = Procedure(
        Name('foo'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      classA.addProcedure(methodA);
      userLib.addClass(classA);

      final classB = Class(name: 'B', fileUri: userLib.fileUri);
      final methodB = Procedure(
        Name('foo'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      classB.addProcedure(methodB);
      userLib.addClass(classB);

      final analysis = runAnalysis();

      expect(
        analysis.familyOf[methodA],
        isNot(same(analysis.familyOf[methodB])),
      );
    });

    test('static member is not in any instance family', () {
      final cls = Class(name: 'A', fileUri: userLib.fileUri);
      final staticMethod = Procedure(
        Name('helper'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
        isStatic: true,
      );
      final instanceMethod = Procedure(
        Name('helper'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      cls
        ..addProcedure(staticMethod)
        ..addProcedure(instanceMethod);
      userLib.addClass(cls);

      final analysis = runAnalysis();

      // Instance method is in a family, static is not (handled as singleton).
      expect(analysis.familyOf[instanceMethod], isNotNull);
      // Static members are singletons — not tracked in familyOf.
      expect(analysis.familyOf[staticMethod], isNull);
    });

    test('unnamed constructor is excluded', () {
      final cls = Class(name: 'A', fileUri: userLib.fileUri);
      final ctor = Constructor(
        FunctionNode(EmptyStatement()),
        name: Name(''),
        fileUri: userLib.fileUri,
      );
      cls.addConstructor(ctor);
      userLib.addClass(cls);

      final analysis = runAnalysis();

      expect(analysis.familyOf[ctor], isNull);
    });

    test('@pragma member is excluded', () {
      final pragmaClass = Class(name: 'pragma', fileUri: coreLib.fileUri);
      coreLib.addClass(pragmaClass);

      final cls = Class(name: 'A', fileUri: userLib.fileUri);
      final method =
          Procedure(
            Name('kept'),
            ProcedureKind.Method,
            FunctionNode(EmptyStatement()),
            fileUri: userLib.fileUri,
          )..addAnnotation(
            ConstantExpression(
              InstanceConstant(pragmaClass.reference, [], {}),
            ),
          );
      cls.addProcedure(method);
      userLib.addClass(cls);

      final analysis = runAnalysis();

      expect(analysis.familyOf[method], isNull);
    });

    test('private names are library-scoped across related classes', () {
      final libAUri = Uri.parse('package:refractor/src/a.dart');
      final libBUri = Uri.parse('package:refractor/src/b.dart');
      final libA = Library(libAUri, fileUri: libAUri);
      final libB = Library(libBUri, fileUri: libBUri);

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

      final analysis = runAnalysis(libraries: [coreLib, libA, libB]);

      expect(analysis.familyOf[baseMethod], isNotNull);
      expect(analysis.familyOf[derivedMethod], isNotNull);
      expect(
        analysis.familyOf[baseMethod],
        isNot(same(analysis.familyOf[derivedMethod])),
      );
    });

    test('sibling implementers of external interface are excluded', () {
      final extUri = Uri.parse('package:external_pkg/api.dart');
      final extLib = Library(extUri, fileUri: extUri);
      final iface = Class(name: 'Api', fileUri: extUri);
      final ifaceMethod = Procedure(
        Name('run'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: extUri,
      );
      iface.addProcedure(ifaceMethod);
      extLib.addClass(iface);

      final classA = Class(
        name: 'ImplA',
        fileUri: userLib.fileUri,
        implementedTypes: [iface.asThisSupertype],
      );
      final runA = Procedure(
        Name('run'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      classA.addProcedure(runA);
      userLib.addClass(classA);

      final classB = Class(
        name: 'ImplB',
        fileUri: userLib.fileUri,
        implementedTypes: [iface.asThisSupertype],
      );
      final runB = Procedure(
        Name('run'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      classB.addProcedure(runB);
      userLib.addClass(classB);

      final analysis = runAnalysis(
        libraries: [coreLib, userLib, extLib],
      );

      // Methods overriding an external interface must not be renamed.
      expect(analysis.familyOf[runA], isNull);
      expect(analysis.familyOf[runB], isNull);
    });
  });
}
