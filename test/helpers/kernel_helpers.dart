import 'package:kernel/kernel.dart';
import 'package:refractor/src/policy/keep_policy.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';
import 'package:refractor/src/project/project_scope.dart';

/// Creates a user library with a `package:refractor/...` URI so that
/// [ProjectScope.containsLibrary] returns `true`.
Library makeUserLibrary([String path = 'src/app.dart']) {
  final uri = Uri.parse('package:refractor/$path');
  return Library(uri, fileUri: uri);
}

/// Creates a synthetic `dart:core` library with stub classes and procedures
/// required by passes.
///
/// Contains: `int` operators, `String`, `Iterable`, `List`, `bool`, and
/// `pragma`.
Library makeDartCoreLibrary() {
  final coreUri = Uri.parse('dart:core');
  final lib = Library(coreUri, fileUri: coreUri);

  // int class with ^ operator
  final intClass = Class(name: 'int', fileUri: coreUri);
  final intType = InterfaceType(intClass, Nullability.nonNullable);
  final numClass = Class(name: 'num', fileUri: coreUri)
    ..addProcedure(
      Procedure(
        Name('+'),
        ProcedureKind.Operator,
        FunctionNode(
          EmptyStatement(),
          positionalParameters: [VariableDeclaration('other', type: intType)],
          returnType: intType,
        ),
        fileUri: coreUri,
      ),
    );
  lib.addClass(numClass);
  final xorProc = Procedure(
    Name('^'),
    ProcedureKind.Operator,
    FunctionNode(
      EmptyStatement(),
      positionalParameters: [VariableDeclaration('other', type: intType)],
      returnType: intType,
    ),
    fileUri: coreUri,
  );
  intClass
    ..addProcedure(xorProc)
    ..addProcedure(
      Procedure(
        Name('>>'),
        ProcedureKind.Operator,
        FunctionNode(
          EmptyStatement(),
          positionalParameters: [VariableDeclaration('other', type: intType)],
          returnType: intType,
        ),
        fileUri: coreUri,
      ),
    )
    ..addProcedure(
      Procedure(
        Name('&'),
        ProcedureKind.Operator,
        FunctionNode(
          EmptyStatement(),
          positionalParameters: [VariableDeclaration('other', type: intType)],
          returnType: intType,
        ),
        fileUri: coreUri,
      ),
    )
    ..addProcedure(
      Procedure(
        Name('+'),
        ProcedureKind.Operator,
        FunctionNode(
          EmptyStatement(),
          positionalParameters: [VariableDeclaration('other', type: intType)],
          returnType: intType,
        ),
        fileUri: coreUri,
      ),
    );
  lib.addClass(intClass);

  // String class with fromCharCodes factory
  final stringClass = Class(name: 'String', fileUri: coreUri);
  final stringType = InterfaceType(stringClass, Nullability.nonNullable);
  final iterableClass = Class(name: 'Iterable', fileUri: coreUri);
  final listClass = Class(name: 'List', fileUri: coreUri);
  final iterableIntType = InterfaceType(
    iterableClass,
    Nullability.nonNullable,
    [intType],
  );
  final listIntType = InterfaceType(listClass, Nullability.nonNullable, [
    intType,
  ]);
  final fromCharCodesProc = Procedure(
    Name('fromCharCodes'),
    ProcedureKind.Factory,
    FunctionNode(
      EmptyStatement(),
      positionalParameters: [
        VariableDeclaration('charCodes', type: iterableIntType),
      ],
      returnType: stringType,
    ),
    fileUri: coreUri,
    isStatic: true,
  );
  stringClass.addProcedure(fromCharCodesProc);
  lib.addClass(stringClass);

  // Iterable class with map method
  final mapProc = Procedure(
    Name('map'),
    ProcedureKind.Method,
    FunctionNode(
      EmptyStatement(),
      positionalParameters: [
        VariableDeclaration(
          'toElement',
          type: FunctionType([intType], intType, Nullability.nonNullable),
        ),
      ],
      returnType: iterableIntType,
    ),
    fileUri: coreUri,
  );
  iterableClass
    ..addProcedure(mapProc)
    ..addProcedure(
      Procedure(
        Name('toList'),
        ProcedureKind.Method,
        FunctionNode(
          EmptyStatement(),
          returnType: listIntType,
        ),
        fileUri: coreUri,
      ),
    )
    ..addProcedure(
      Procedure(
        Name('reversed'),
        ProcedureKind.Getter,
        FunctionNode(
          EmptyStatement(),
          returnType: iterableIntType,
        ),
        fileUri: coreUri,
      ),
    );
  lib.addClass(iterableClass);

  // List class with reversed getter.
  listClass
    ..addProcedure(
      Procedure(
        Name('reversed'),
        ProcedureKind.Getter,
        FunctionNode(
          EmptyStatement(),
          returnType: iterableIntType,
        ),
        fileUri: coreUri,
      ),
    )
    ..addProcedure(
      Procedure(
        Name('add'),
        ProcedureKind.Method,
        FunctionNode(
          EmptyStatement(),
          positionalParameters: [
            VariableDeclaration('value', type: intType),
          ],
          requiredParameterCount: 1,
          returnType: const VoidType(),
        ),
        fileUri: coreUri,
      ),
    )
    ..addProcedure(
      Procedure(
        Name('of'),
        ProcedureKind.Factory,
        FunctionNode(
          EmptyStatement(),
          positionalParameters: [
            VariableDeclaration('elements', type: iterableIntType),
          ],
          requiredParameterCount: 1,
          returnType: listIntType,
        ),
        fileUri: coreUri,
        isStatic: true,
      ),
    );
  lib.addClass(listClass);

  // bool class (needed for dead code branch)
  final boolClass = Class(name: 'bool', fileUri: coreUri);
  lib.addClass(boolClass);

  final pragmaClass = Class(name: 'pragma', fileUri: coreUri)
    ..addField(
      Field.immutable(
        Name('name'),
        type: stringType,
        fileUri: coreUri,
      ),
    )
    ..addField(
      Field.immutable(
        Name('options'),
        fileUri: coreUri,
      ),
    );
  lib.addClass(pragmaClass);

  // top-level identical(Object? a, Object? b) -> bool
  final objectClass = Class(name: 'Object', fileUri: coreUri);
  lib.addClass(objectClass);
  final objectType = InterfaceType(objectClass, Nullability.nullable);
  final boolType = InterfaceType(boolClass, Nullability.nonNullable);
  lib.addProcedure(
    Procedure(
      Name('identical'),
      ProcedureKind.Method,
      FunctionNode(
        EmptyStatement(),
        positionalParameters: [
          VariableDeclaration('a', type: objectType),
          VariableDeclaration('b', type: objectType),
        ],
        requiredParameterCount: 2,
        returnType: boolType,
      ),
      fileUri: coreUri,
      isStatic: true,
    ),
  );

  return lib;
}

Library makeDartConvertLibrary() {
  final convertUri = Uri.parse('dart:convert');
  final coreUri = Uri.parse('dart:core');
  final lib = Library(convertUri, fileUri: convertUri);

  final intClass = Class(name: 'int', fileUri: coreUri);
  final stringClass = Class(name: 'String', fileUri: coreUri);
  final listClass = Class(name: 'List', fileUri: coreUri);
  final utf8CodecClass = Class(name: 'Utf8Codec', fileUri: convertUri);
  final intType = InterfaceType(intClass, Nullability.nonNullable);
  final stringType = InterfaceType(stringClass, Nullability.nonNullable);
  final listIntType = InterfaceType(listClass, Nullability.nonNullable, [
    intType,
  ]);

  utf8CodecClass
    ..addProcedure(
      Procedure(
        Name('decode'),
        ProcedureKind.Method,
        FunctionNode(
          EmptyStatement(),
          positionalParameters: [
            VariableDeclaration('codeUnits', type: listIntType),
          ],
          requiredParameterCount: 1,
          returnType: stringType,
        ),
        fileUri: convertUri,
      ),
    )
    ..addConstructor(
      Constructor(
        FunctionNode(EmptyStatement()),
        name: Name(''),
        fileUri: convertUri,
        isConst: true,
      ),
    );
  lib
    ..addClass(utf8CodecClass)
    ..addField(
      Field.immutable(
        Name('utf8'),
        initializer: NullLiteral(),
        type: InterfaceType(utf8CodecClass, Nullability.nonNullable),
        fileUri: convertUri,
      ),
    );

  return lib;
}

/// Creates a [ProjectScope] with defaults suitable for tests.
ProjectScope makeProjectScope() {
  return ProjectScope(
    projectRootUri: Uri.directory('/virtual/project'),
    projectPackageName: 'refractor',
  );
}

/// Creates an [ObfuscationScope] over the default test project scope with the
/// given [keep] policy (defaults to keeping nothing).
ObfuscationScope makeObfuscationScope({KeepPolicy keep = KeepPolicy.empty}) {
  return ObfuscationScope(project: makeProjectScope(), keep: keep);
}

/// Creates a [Procedure] with the given [name] and adds it to [cls].
Procedure makeProcedure(String name, Class cls) {
  final proc = Procedure(
    Name(name),
    ProcedureKind.Method,
    FunctionNode(EmptyStatement()),
    fileUri: cls.fileUri,
  );
  cls.addProcedure(proc);
  return proc;
}

/// Bundles the given libraries into a [Component].
/// Adds a stand-in for the injected `refractorDecode(List<int> bytes, int key)`
/// helper to [userLib], with the real signature so the string_encrypt
/// transformer can type its byte lists from the `bytes` parameter.
Procedure addDecodeHelperStandIn({
  required Library coreLib,
  required Library userLib,
}) {
  Class coreClass(String name) =>
      coreLib.classes.firstWhere((c) => c.name == name);
  final intType = InterfaceType(coreClass('int'), Nullability.nonNullable);
  final procedure = Procedure(
    Name('refractorDecode', userLib),
    ProcedureKind.Method,
    FunctionNode(
      EmptyStatement(),
      positionalParameters: [
        VariableDeclaration(
          'bytes',
          type: InterfaceType(coreClass('List'), Nullability.nonNullable, [
            intType,
          ]),
          isSynthesized: true,
        ),
        VariableDeclaration('key', type: intType, isSynthesized: true),
      ],
    ),
    fileUri: userLib.fileUri,
    isStatic: true,
  );
  userLib.addProcedure(procedure);
  return procedure;
}

Component makeComponent({
  required Library coreLib,
  required Library userLib,
  List<Library> extraLibraries = const [],
}) {
  return Component(libraries: [coreLib, ...extraLibraries, userLib])
    ..setMainMethodAndMode(null, true);
}

Expression makePragmaAnnotation(
  Library coreLib, {
  required String name,
}) {
  final pragmaClass = coreLib.classes.firstWhere((cls) => cls.name == 'pragma');
  final pragmaNameField = pragmaClass.fields.firstWhere(
    (field) => field.name.text == 'name',
  );
  final pragmaOptionsField = pragmaClass.fields.firstWhere(
    (field) => field.name.text == 'options',
  );

  return ConstantExpression(
    InstanceConstant(
      pragmaClass.reference,
      const [],
      <Reference, Constant>{
        pragmaNameField.fieldReference: StringConstant(name),
        pragmaOptionsField.fieldReference: NullConstant(),
      },
    ),
  );
}

Library makeRefractorAnnotationLibrary() {
  final uri = Uri.parse(
    'package:refractor_annotation/refractor_annotation.dart',
  );
  final lib = Library(uri, fileUri: uri);

  final refractorClass = Class(name: 'Refractor', fileUri: uri);
  final keepClass = Class(name: 'RefractorKeep', fileUri: uri)
    ..addConstructor(
      Constructor(
        FunctionNode(EmptyStatement()),
        name: Name(''),
        fileUri: uri,
        isConst: true,
      ),
    );

  lib
    ..addClass(refractorClass)
    ..addClass(keepClass);

  return lib;
}

Expression makeRefractorKeepAnnotation(Library annotationLib) {
  final keepClass = annotationLib.classes.firstWhere(
    (cls) => cls.name == 'RefractorKeep',
  );

  return ConstantExpression(
    InstanceConstant(keepClass.reference, const [], const {}),
  );
}
