import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/kernel_toolkit/sdk/sdk_index.dart';
import 'package:refractor/src/exceptions/refractor_exception.dart';
import 'package:test/test.dart';

import '../../../helpers/kernel_helpers.dart';

void main() {
  late SdkIndex sdk;
  late Library coreLib;

  setUp(() {
    coreLib = makeDartCoreLibrary();
    final component = makeComponent(
      coreLib: coreLib,
      userLib: makeUserLibrary(),
      extraLibraries: [makeDartConvertLibrary()],
    );
    sdk = SdkIndex(component);
  });

  test('requireLibrary returns the library or throws', () {
    expect(sdk.requireLibrary('dart:core'), same(coreLib));
    expect(
      () => sdk.requireLibrary('dart:missing'),
      throwsA(isA<CompilationException>()),
    );
  });

  test('requireClass returns the class or throws', () {
    expect(sdk.requireClass('dart:core', 'int').name, 'int');
    expect(
      () => sdk.requireClass('dart:core', 'Nope'),
      throwsA(isA<CompilationException>()),
    );
  });

  test('requireProcedure returns the procedure or throws', () {
    final intClass = sdk.requireClass('dart:core', 'int');
    expect(sdk.requireProcedure(intClass, '^').name.text, '^');
    expect(
      () => sdk.requireProcedure(intClass, 'nope'),
      throwsA(isA<CompilationException>()),
    );
  });

  test('requireField returns the field or throws', () {
    final pragmaClass = sdk.requireClass('dart:core', 'pragma');
    expect(sdk.requireField(pragmaClass, 'name').name.text, 'name');
    expect(
      () => sdk.requireField(pragmaClass, 'nope'),
      throwsA(isA<CompilationException>()),
    );
  });

  test('requireSingleConstructor returns the sole constructor or throws', () {
    final utf8Codec = sdk.requireClass('dart:convert', 'Utf8Codec');
    expect(sdk.requireSingleConstructor(utf8Codec), isNotNull);

    final noConstructors = Class(name: 'NoCtor', fileUri: coreLib.fileUri);
    expect(
      () => sdk.requireSingleConstructor(noConstructors),
      throwsA(isA<CompilationException>()),
    );
  });

  test('interfaceType builds a type with the given arguments', () {
    final intClass = sdk.requireClass('dart:core', 'int');
    final listClass = sdk.requireClass('dart:core', 'List');
    final listOfInt = sdk.interfaceType(
      listClass,
      typeArguments: [sdk.interfaceType(intClass)],
    );

    expect(listOfInt.classNode, same(listClass));
    expect(listOfInt.typeArguments.single, isA<InterfaceType>());
  });
}
