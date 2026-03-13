import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/passes/rename/declaration_collector.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_pass_options.dart';
import 'package:refractor/src/engine/runner/obfuscation_target.dart';
import 'package:test/test.dart';

import '../../../helpers/kernel_helpers.dart';

void main() {
  group('DeclarationCollector', () {
    late Library coreLib;
    late Library userLib;
    late ObfuscationTarget target;

    setUp(() {
      coreLib = makeDartCoreLibrary();
      userLib = makeUserLibrary();
      target = ObfuscationTarget(
        projectRootUri: Uri.directory('/virtual/project'),
        projectPackageName: 'refractor',
      );
    });

    DeclarationCollector runCollector({
      RenamePassOptions options = const RenamePassOptions(),
    }) {
      final component = makeComponent(coreLib: coreLib, userLib: userLib);
      final collector = DeclarationCollector(target, options)
        ..collect(component);
      return collector;
    }

    test('collects class scopes with instance and static members', () {
      final cls = Class(name: 'Svc', fileUri: userLib.fileUri);
      final instance = Procedure(
        Name('doWork'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      final staticMember = Procedure(
        Name('helper'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
        isStatic: true,
      );
      cls
        ..addProcedure(instance)
        ..addProcedure(staticMember);
      userLib.addClass(cls);

      final collector = runCollector();

      expect(collector.classScopes, hasLength(1));
      final scope = collector.classScopes.first;
      expect(scope.node, same(cls));
      expect(scope.instanceMembers, contains(instance));
      expect(scope.staticMembers, contains(staticMember));
    });

    test('collects top-level procedures', () {
      final proc = Procedure(
        Name('topFn'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(proc);

      final collector = runCollector(
        options: const RenamePassOptions(preserveMain: false),
      );

      expect(collector.topLevelMembers, contains(proc));
    });

    test('preserveMain skips main procedure', () {
      final mainProc = Procedure(
        Name('main'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(mainProc);

      final collector = runCollector();

      expect(collector.topLevelMembers, isNot(contains(mainProc)));
    });

    test('preserveMain=false includes main procedure', () {
      final mainProc = Procedure(
        Name('main'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(mainProc);

      final collector = runCollector(
        options: const RenamePassOptions(preserveMain: false),
      );

      expect(collector.topLevelMembers, contains(mainProc));
    });

    test('skips @pragma-annotated members', () {
      final pragmaClass = Class(name: 'pragma', fileUri: coreLib.fileUri);
      coreLib.addClass(pragmaClass);

      final cls = Class(name: 'A', fileUri: userLib.fileUri);
      final kept =
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
      cls.addProcedure(kept);
      userLib.addClass(cls);

      final collector = runCollector();

      final scope = collector.classScopes.first;
      expect(scope.instanceMembers, isNot(contains(kept)));
    });

    test('skips dart: libraries entirely', () {
      final collector = runCollector();

      // No class scopes from dart:core
      for (final cs in collector.classScopes) {
        expect(
          cs.node.enclosingLibrary.importUri.scheme,
          isNot('dart'),
        );
      }
    });

    test('collects named constructors', () {
      final cls = Class(name: 'Widget', fileUri: userLib.fileUri);
      final ctor = Constructor(
        FunctionNode(EmptyStatement()),
        name: Name('create'),
        fileUri: userLib.fileUri,
      );
      cls.addConstructor(ctor);
      userLib.addClass(cls);

      final collector = runCollector();

      final scope = collector.classScopes.first;
      expect(scope.constructors, contains(ctor));
    });

    test('skips unnamed constructors', () {
      final cls = Class(name: 'Widget', fileUri: userLib.fileUri);
      final ctor = Constructor(
        FunctionNode(EmptyStatement()),
        name: Name(''),
        fileUri: userLib.fileUri,
      );
      cls.addConstructor(ctor);
      userLib.addClass(cls);

      final collector = runCollector();

      final scope = collector.classScopes.first;
      expect(scope.constructors, isNot(contains(ctor)));
    });

    test('skips instance members that override external supertypes', () {
      // Add toString() to the dart:core Object class.
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

      // User class extends Object (via supertype) and overrides toString.
      final cls = Class(
        name: 'MyClass',
        fileUri: userLib.fileUri,
        supertype: objectClass.asThisSupertype,
      );
      final toStringOverride = Procedure(
        Name('toString'),
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
        ..addProcedure(toStringOverride)
        ..addProcedure(userOnly);
      userLib.addClass(cls);

      final collector = runCollector();

      final scope = collector.classScopes.firstWhere(
        (s) => s.node == cls,
      );
      expect(
        scope.instanceMembers,
        isNot(contains(toStringOverride)),
        reason: 'toString overrides Object.toString and must not be renamed',
      );
      expect(scope.instanceMembers, contains(userOnly));
    });

    test('collects variables', () {
      final proc = Procedure(
        Name('fn'),
        ProcedureKind.Method,
        FunctionNode(
          Block([VariableDeclaration('myVar')]),
        ),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(proc);

      final collector = runCollector(
        options: const RenamePassOptions(preserveMain: false),
      );

      expect(
        collector.variables.any((v) => v.name == 'myVar'),
        isTrue,
      );
    });
  });
}
