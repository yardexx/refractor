import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/name_generator.dart';
import 'package:refractor/src/engine/runner/pass_context.dart';
import 'package:refractor/src/engine/runner/pass_options.dart';
import 'package:refractor/src/engine/symbol_table.dart';

/// Creates a user library with a `package:refractor/...` URI so that
/// [PassContext.shouldObfuscateLibrary] returns `true`.
Library makeUserLibrary([String path = 'src/app.dart']) {
  final uri = Uri.parse('package:refractor/$path');
  return Library(uri, fileUri: uri);
}

/// Creates a synthetic `dart:core` library with stub classes and procedures
/// required by passes.
///
/// Contains: `int` (with `^` operator), `String` (with `fromCharCodes`),
/// `Iterable` (with `map`), `List`, and `bool`.
Library makeDartCoreLibrary() {
  final coreUri = Uri.parse('dart:core');
  final lib = Library(coreUri, fileUri: coreUri);

  // int class with ^ operator
  final intClass = Class(name: 'int', fileUri: coreUri);
  final intType = InterfaceType(intClass, Nullability.nonNullable);
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
  intClass.addProcedure(xorProc);
  lib.addClass(intClass);

  // String class with fromCharCodes factory
  final stringClass = Class(name: 'String', fileUri: coreUri);
  final stringType = InterfaceType(stringClass, Nullability.nonNullable);
  final iterableClass = Class(name: 'Iterable', fileUri: coreUri);
  final iterableIntType = InterfaceType(
    iterableClass,
    Nullability.nonNullable,
    [intType],
  );
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
  iterableClass.addProcedure(mapProc);
  lib.addClass(iterableClass);

  // List class (no methods needed)
  final listClass = Class(name: 'List', fileUri: coreUri);
  lib.addClass(listClass);

  // bool class (needed for dead code branch)
  final boolClass = Class(name: 'bool', fileUri: coreUri);
  lib.addClass(boolClass);

  return lib;
}

/// Creates a [PassContext] with fresh [SymbolTable] and [NameGenerator].
PassContext makePassContext([PassOptions? options]) {
  return PassContext(
    symbolTable: SymbolTable(),
    nameGenerator: NameGenerator(),
    options: options ?? const PassOptions(),
  );
}

/// Bundles the given libraries into a [Component].
Component makeComponent({
  required Library coreLib,
  required Library userLib,
}) {
  return Component(libraries: [coreLib, userLib])
    ..setMainMethodAndMode(null, true);
}
