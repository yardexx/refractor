import 'package:glob/glob.dart';
import 'package:kernel/ast.dart';
import 'package:refractor/src/policy/keep_resolver.dart';
import 'package:refractor/src/policy/keep_source.dart';
import 'package:refractor/src/project/project_scope.dart';
import 'package:test/test.dart';

import '../helpers/kernel_helpers.dart';

void main() {
  group('KeepResolver', () {
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

    KeepResolver resolver(
      Component component, {
      List<Glob> globalExcludes = const [],
    }) {
      return KeepResolver(
        component: component,
        projectScope: projectScope,
        globalExcludes: globalExcludes,
      );
    }

    test('honors only the declared keep sources', () {
      // The core decoupling property: a pass that declares only `excludes`
      // must not pick up annotation or entry-point keeps.
      final library = _userLibrary('src/annotated.dart');
      final cls = Class(name: 'Annotated', fileUri: library.fileUri)
        ..addAnnotation(makeRefractorKeepAnnotation(annotationLib));
      library.addClass(cls);
      final component = _component([coreLib, annotationLib, library]);
      final keepResolver = resolver(component);

      expect(
        keepResolver
            .resolve(const {KeepSource.annotations}, const [])
            .isClassKept(cls),
        isTrue,
      );
      expect(
        keepResolver
            .resolve(const {KeepSource.excludes}, const [])
            .isClassKept(cls),
        isFalse,
      );
    });

    test('global excludes keep the library, others are untouched', () {
      final excludedLib = _userLibrary('src/excluded.dart');
      final includedLib = _userLibrary('src/included.dart');
      final component = _component([
        coreLib,
        annotationLib,
        excludedLib,
        includedLib,
      ]);

      final keep = resolver(
        component,
        globalExcludes: [Glob('lib/src/excluded.dart')],
      ).resolve(const {KeepSource.excludes}, const []);

      expect(keep.isLibraryKept(excludedLib), isTrue);
      expect(keep.isLibraryKept(includedLib), isFalse);
    });

    test(
      'pass-specific excludes apply only to the pass that supplies them',
      () {
        final excludedLib = _userLibrary('src/rename_only.dart');
        final component = _component([coreLib, annotationLib, excludedLib]);
        final keepResolver = resolver(component);

        final withExclude = keepResolver.resolve(
          const {KeepSource.excludes},
          const [
            'lib/src/rename_only.dart',
          ],
        );
        final withoutExclude = keepResolver.resolve(
          const {KeepSource.excludes},
          const [],
        );

        expect(withExclude.isLibraryKept(excludedLib), isTrue);
        expect(withoutExclude.isLibraryKept(excludedLib), isFalse);
      },
    );

    test('matches file uri libraries by workspace-relative path', () {
      final fileLibrary = Library(
        Uri.parse('file:///virtual/project/lib/src/file_only.dart'),
        fileUri: Uri.parse('file:///virtual/project/lib/src/file_only.dart'),
      );
      final component = _component([coreLib, annotationLib, fileLibrary]);

      final keep = resolver(component).resolve(
        const {KeepSource.excludes},
        const [
          'lib/src/file_only.dart',
        ],
      );

      expect(keep.isLibraryKept(fileLibrary), isTrue);
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

        final keep = resolver(component).resolve(
          const {KeepSource.annotations},
          const [],
        );

        expect(keep.isClassKept(cls), isTrue);
        expect(keep.isMemberKept(method), isTrue);
        expect(keep.isMemberKept(ctor), isTrue);
      },
    );

    test('member-level keep stays independent from sibling members', () {
      final library = _userLibrary('src/property.dart');
      final cls = Class(name: 'Holder', fileUri: library.fileUri);
      final field = Field.mutable(Name('value'), fileUri: library.fileUri);
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

      final keep = resolver(component).resolve(
        const {KeepSource.annotations},
        const [],
      );

      expect(keep.isMemberKept(getter), isTrue);
      expect(keep.isMemberKept(field), isFalse);
      expect(keep.isMemberKept(setter), isFalse);
    });

    test('annotated top-level field is kept', () {
      final library = _userLibrary('src/top_level_field.dart');
      final field = Field.mutable(Name('apiKey'), fileUri: library.fileUri)
        ..addAnnotation(makeRefractorKeepAnnotation(annotationLib));
      library.addField(field);
      final component = _component([coreLib, annotationLib, library]);

      final keep = resolver(component).resolve(
        const {KeepSource.annotations},
        const [],
      );

      expect(keep.isMemberKept(field), isTrue);
    });

    test('generic pragma does not keep annotation targets', () {
      final pragmaClass = Class(name: 'pragma', fileUri: coreLib.fileUri);
      coreLib.addClass(pragmaClass);

      final library = _userLibrary('src/pragma_only.dart');
      final cls = Class(name: 'Annotated', fileUri: library.fileUri)
        ..addAnnotation(
          ConstantExpression(
            InstanceConstant(pragmaClass.reference, const [], const {}),
          ),
        );
      library.addClass(cls);
      final component = _component([coreLib, annotationLib, library]);

      final keep = resolver(component).resolve(
        const {KeepSource.annotations},
        const [],
      );

      expect(keep.isClassKept(cls), isFalse);
    });

    test('entry-point source keeps the component main method only', () {
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

      final keep = resolver(component).resolve(
        const {KeepSource.entryPoint},
        const [],
      );

      expect(keep.isMemberKept(main), isTrue);
      expect(keep.isMemberKept(helper), isFalse);
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

      final keep = resolver(component).resolve(
        const {KeepSource.entryPoint},
        const [],
      );

      expect(keep.isMemberKept(entrypoint), isTrue);
      expect(keep.isMemberKept(methodMain), isFalse);
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
