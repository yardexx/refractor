import 'package:kernel/ast.dart';
import 'package:refractor/src/config/model/refractor_config.dart';
import 'package:refractor/src/policy/policy_resolver.dart';
import 'package:refractor/src/project/project_scope.dart';
import 'package:test/test.dart';

import '../helpers/kernel_helpers.dart';

void main() {
  group('PolicyResolver', () {
    late ProjectScope projectScope;
    late Library coreLib;
    late Library annotationLib;

    setUp(() {
      projectScope = ProjectScope(
        projectRootUri: Uri(scheme: 'file', path: '/virtual/project/'),
        projectPackageName: 'refractor',
      );
      coreLib = Library(
        Uri.parse('dart:core'),
        fileUri: Uri.parse('dart:core'),
      );
      annotationLib = makeRefractorAnnotationLibrary();
    });

    test('keeps globally excluded libraries for all passes', () {
      final excludedLib = _userLibrary('src/excluded.dart');
      final includedLib = _userLibrary('src/included.dart');
      final component = _component([
        coreLib,
        annotationLib,
        excludedLib,
        includedLib,
      ]);
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
      final component = _component([coreLib, annotationLib, excludedLib]);
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

    test(
      'class-level keep annotation propagates to members and constructors',
      () {
        final library = _userLibrary('src/annotated_class.dart');
        final cls = Class(name: 'Annotated', fileUri: library.fileUri)
          ..addAnnotation(makeRefractorKeepAnnotation(annotationLib));
        final method = Procedure(
          Name('call'),
          ProcedureKind.Method,
          FunctionNode(EmptyStatement()),
          fileUri: library.fileUri,
        );
        final ctor = Constructor(
          FunctionNode(EmptyStatement()),
          name: Name('named'),
          fileUri: library.fileUri,
        );
        cls
          ..addProcedure(method)
          ..addConstructor(ctor);
        library.addClass(cls);
        final component = _component([coreLib, annotationLib, library]);

        final policy = PolicyResolver().resolve(
          component: component,
          config: _renameConfig(),
          projectScope: projectScope,
        );

        expect(policy.rename.isClassKept(cls), isTrue);
        expect(policy.rename.isMemberKept(method), isTrue);
        expect(policy.rename.isMemberKept(ctor), isTrue);
      },
    );

    test('member-level keep stays independent from sibling members', () {
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
      )..addAnnotation(makeRefractorKeepAnnotation(annotationLib));
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
      final component = _component([coreLib, annotationLib, library]);

      final policy = PolicyResolver().resolve(
        component: component,
        config: _renameConfig(),
        projectScope: projectScope,
      );

      expect(policy.rename.isMemberKept(getter), isTrue);
      expect(policy.rename.isMemberKept(field), isFalse);
      expect(policy.rename.isMemberKept(setter), isFalse);
    });

    test('annotated top-level field is kept', () {
      final library = _userLibrary('src/top_level_field.dart');
      final field = Field.mutable(
        Name('apiKey'),
        fileUri: library.fileUri,
      )..addAnnotation(makeRefractorKeepAnnotation(annotationLib));
      library.addField(field);
      final component = _component([coreLib, annotationLib, library]);

      final policy = PolicyResolver().resolve(
        component: component,
        config: _renameConfig(),
        projectScope: projectScope,
      );

      expect(policy.rename.isMemberKept(field), isTrue);
    });

    test('generic pragma does not keep rename targets', () {
      final pragmaClass = Class(name: 'pragma', fileUri: coreLib.fileUri);
      coreLib.addClass(pragmaClass);

      final library = _userLibrary('src/pragma_only.dart');
      final cls = Class(name: 'Annotated', fileUri: library.fileUri)
        ..addAnnotation(
          ConstantExpression(
            InstanceConstant(pragmaClass.reference, const [], const {}),
          ),
        );
      final method =
          Procedure(
            Name('call'),
            ProcedureKind.Method,
            FunctionNode(EmptyStatement()),
            fileUri: library.fileUri,
          )..addAnnotation(
            ConstantExpression(
              InstanceConstant(pragmaClass.reference, const [], const {}),
            ),
          );
      cls.addProcedure(method);
      library.addClass(cls);
      final component = _component([coreLib, annotationLib, library]);

      final policy = PolicyResolver().resolve(
        component: component,
        config: _renameConfig(),
        projectScope: projectScope,
      );

      expect(policy.rename.isClassKept(cls), isFalse);
      expect(policy.rename.isMemberKept(method), isFalse);
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
      final component = _component(
        [coreLib, annotationLib, library],
        mainMethod: main,
      );

      final policy = PolicyResolver().resolve(
        component: component,
        config: _renameConfig(),
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
        [coreLib, annotationLib, library],
        mainMethod: entrypoint,
      );

      final policy = PolicyResolver().resolve(
        component: component,
        config: _renameConfig(),
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
      final component = _component([coreLib, annotationLib, fileLibrary]);
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

    test('compiles string-encrypt exclude_patterns into literal policy', () {
      final library = _userLibrary('src/strings.dart');
      final component = _component([coreLib, annotationLib, library]);
      final config = RefractorConfig.fromYaml('''
refractor:
  passes:
    string_encrypt:
      exclude_patterns:
        - KEEP_ME
''');

      final policy = PolicyResolver().resolve(
        component: component,
        config: config,
        projectScope: projectScope,
      );

      expect(
        policy.stringEncrypt.shouldEncryptLiteral(StringLiteral('hello')),
        isTrue,
      );
      expect(
        policy.stringEncrypt.shouldEncryptLiteral(StringLiteral('KEEP_ME')),
        isFalse,
      );
    });
  });
}

RefractorConfig _renameConfig() {
  return RefractorConfig.fromYaml('''
refractor:
  passes:
    rename: true
''');
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
