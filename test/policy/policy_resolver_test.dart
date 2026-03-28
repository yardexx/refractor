import 'package:kernel/ast.dart';
import 'package:refractor/src/config/model/refractor_config.dart';
import 'package:refractor/src/policy/policy_resolver.dart';
import 'package:refractor/src/project/project_scope.dart';
import 'package:test/test.dart';

void main() {
  group('PolicyResolver', () {
    late ProjectScope projectScope;
    late Library coreLib;
    late Class pragmaClass;

    setUp(() {
      projectScope = ProjectScope(
        projectRootUri: Uri(scheme: 'file', path: '/virtual/project/'),
        projectPackageName: 'refractor',
      );
      coreLib = Library(
        Uri.parse('dart:core'),
        fileUri: Uri.parse('dart:core'),
      );
      pragmaClass = Class(name: 'pragma', fileUri: coreLib.fileUri);
      coreLib.addClass(pragmaClass);
    });

    test('keeps globally excluded libraries for all passes', () {
      final excludedLib = _userLibrary('src/excluded.dart');
      final includedLib = _userLibrary('src/included.dart');
      final component = _component([coreLib, excludedLib, includedLib]);
      final config = RefractorConfig.fromYaml('''
refractor:
  exclude:
    - lib/src/excluded.dart
  passes:
    rename: true
    string_encrypt: true
''');

      final policy = PolicyResolver().resolve(
        component: component,
        config: config,
        projectScope: projectScope,
      );

      expect(policy.rename.isLibraryKept(excludedLib), isTrue);
      expect(policy.stringEncrypt.isLibraryKept(excludedLib), isTrue);
      expect(policy.rename.isLibraryKept(includedLib), isFalse);
      expect(policy.stringEncrypt.isLibraryKept(includedLib), isFalse);
    });

    test('keeps pass-specific exclusions only for the targeted pass', () {
      final excludedLib = _userLibrary('src/rename_only.dart');
      final component = _component([coreLib, excludedLib]);
      final config = RefractorConfig.fromYaml('''
refractor:
  passes:
    rename:
      exclude:
        - lib/src/rename_only.dart
    string_encrypt: true
''');

      final policy = PolicyResolver().resolve(
        component: component,
        config: config,
        projectScope: projectScope,
      );

      expect(policy.rename.isLibraryKept(excludedLib), isTrue);
      expect(policy.stringEncrypt.isLibraryKept(excludedLib), isFalse);
    });

    test('class-level pragma keep propagates to members', () {
      final library = _userLibrary('src/annotated_class.dart');
      final cls = Class(name: 'Annotated', fileUri: library.fileUri)
        ..addAnnotation(_pragmaAnnotation(pragmaClass));
      final method = Procedure(
        Name('call'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: library.fileUri,
      );
      cls.addProcedure(method);
      library.addClass(cls);
      final component = _component([coreLib, library]);
      final config = RefractorConfig.fromYaml('''
refractor:
  passes:
    rename: true
''');

      final policy = PolicyResolver().resolve(
        component: component,
        config: config,
        projectScope: projectScope,
      );

      expect(policy.rename.isClassKept(cls), isTrue);
      expect(policy.rename.isMemberKept(method), isTrue);
    });

    test('getter and setter keeps stay independent from field keeps', () {
      final library = _userLibrary('src/property.dart');
      final cls = Class(name: 'Holder', fileUri: library.fileUri);
      final field = Field.mutable(
        Name('value'),
        fileUri: library.fileUri,
      );
      final getter = Procedure(
        Name('value'),
        ProcedureKind.Getter,
        FunctionNode(ReturnStatement(IntLiteral(1))),
        fileUri: library.fileUri,
      )..addAnnotation(_pragmaAnnotation(pragmaClass));
      final setter = Procedure(
        Name('value'),
        ProcedureKind.Setter,
        FunctionNode(
          EmptyStatement(),
          positionalParameters: [VariableDeclaration('next')],
          requiredParameterCount: 1,
        ),
        fileUri: library.fileUri,
      );
      cls
        ..addField(field)
        ..addProcedure(getter)
        ..addProcedure(setter);
      library.addClass(cls);
      final component = _component([coreLib, library]);
      final config = RefractorConfig.fromYaml('''
refractor:
  passes:
    rename: true
''');

      final policy = PolicyResolver().resolve(
        component: component,
        config: config,
        projectScope: projectScope,
      );

      expect(policy.rename.isMemberKept(getter), isTrue);
      expect(policy.rename.isMemberKept(field), isFalse);
      expect(policy.rename.isMemberKept(setter), isFalse);
    });

    test('keeps the component main method', () {
      final library = _userLibrary('src/main.dart');
      final main = Procedure(
        Name('main'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: library.fileUri,
        isStatic: true,
      );
      final helper = Procedure(
        Name('helper'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: library.fileUri,
        isStatic: true,
      );
      library
        ..addProcedure(main)
        ..addProcedure(helper);
      final component = _component([coreLib, library], mainMethod: main);
      final config = RefractorConfig.fromYaml('''
refractor:
  passes:
    rename: true
''');

      final policy = PolicyResolver().resolve(
        component: component,
        config: config,
        projectScope: projectScope,
      );

      expect(policy.rename.isMemberKept(main), isTrue);
      expect(policy.rename.isMemberKept(helper), isFalse);
    });

    test('does not keep other procedures named main', () {
      final library = _userLibrary('src/main.dart');
      final entrypoint = Procedure(
        Name('main'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: library.fileUri,
        isStatic: true,
      );
      final cls = Class(name: 'Holder', fileUri: library.fileUri);
      final methodMain = Procedure(
        Name('main'),
        ProcedureKind.Method,
        FunctionNode(EmptyStatement()),
        fileUri: library.fileUri,
      );
      cls.addProcedure(methodMain);
      library
        ..addProcedure(entrypoint)
        ..addClass(cls);
      final component = _component(
        [coreLib, library],
        mainMethod: entrypoint,
      );

      final policy = PolicyResolver().resolve(
        component: component,
        config: RefractorConfig.fromYaml('''
refractor:
  passes:
    rename: true
'''),
        projectScope: projectScope,
      );

      expect(policy.rename.isMemberKept(entrypoint), isTrue);
      expect(policy.rename.isMemberKept(methodMain), isFalse);
    });

    test('matches file uri libraries by workspace-relative path', () {
      final fileLibrary = Library(
        Uri.parse('file:///virtual/project/lib/src/file_only.dart'),
        fileUri: Uri.parse('file:///virtual/project/lib/src/file_only.dart'),
      );
      final component = _component([coreLib, fileLibrary]);
      final config = RefractorConfig.fromYaml('''
refractor:
  passes:
    rename:
      exclude:
        - lib/src/file_only.dart
''');

      final policy = PolicyResolver().resolve(
        component: component,
        config: config,
        projectScope: projectScope,
      );

      expect(policy.rename.isLibraryKept(fileLibrary), isTrue);
    });
  });
}

Library _userLibrary(String path) {
  final uri = Uri.parse('package:refractor/$path');
  return Library(uri, fileUri: uri);
}

Component _component(
  List<Library> libraries, {
  Procedure? mainMethod,
}) {
  return Component(libraries: libraries)
    ..setMainMethodAndMode(mainMethod?.reference, true);
}

Expression _pragmaAnnotation(Class pragmaClass) {
  return ConstantExpression(
    InstanceConstant(pragmaClass.reference, const [], const {}),
  );
}
