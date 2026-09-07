import 'package:kernel/ast.dart';
import 'package:refractor/src/exceptions/refractor_exception.dart';

final class SdkIndex {
  SdkIndex(this._component);

  final Component _component;

  Library requireLibrary(String importUri) {
    for (final library in _component.libraries) {
      if (library.importUri.toString() == importUri) return library;
    }
    throw CompilationException('SDK library not found: $importUri');
  }

  Class requireClass(String importUri, String name) {
    for (final cls in requireLibrary(importUri).classes) {
      if (cls.name == name) return cls;
    }
    throw CompilationException('SDK class not found: $importUri::$name');
  }

  Procedure requireProcedure(Class cls, String name) {
    for (final procedure in cls.procedures) {
      if (procedure.name.text == name) return procedure;
    }
    throw CompilationException('SDK procedure not found: ${cls.name}.$name');
  }

  Field requireField(Class cls, String name) {
    for (final field in cls.fields) {
      if (field.name.text == name) return field;
    }
    throw CompilationException('SDK field not found: ${cls.name}.$name');
  }

  Constructor requireSingleConstructor(Class cls) {
    final constructors = cls.constructors;
    if (constructors.length != 1) {
      throw CompilationException(
        'Expected a single constructor on ${cls.name}, '
        'found ${constructors.length}.',
      );
    }
    return constructors.single;
  }

  InterfaceType interfaceType(
    Class cls, {
    List<DartType> typeArguments = const [],
    Nullability nullability = Nullability.nonNullable,
  }) {
    return InterfaceType(cls, nullability, typeArguments);
  }
}
