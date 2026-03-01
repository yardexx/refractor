import 'dart:convert';

import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/passes/string_encrypt/string_encrypt_transformer.dart';
import 'package:refractor/src/engine/runner/pass.dart';
import 'package:refractor/src/engine/runner/pass_context.dart';

/// Obfuscation pass that replaces plaintext [StringLiteral] nodes with a
/// call to an injected decode helper, so strings are not visible in the binary.
///
/// Encoding: XOR each UTF-8 byte with a fixed key (configurable, default 0x5A).
/// At runtime, the injected `_obfDecode$` reverses this to recover the
/// original string.
class StringEncryptPass extends Pass {
  StringEncryptPass({this.xorKey = 0x5A});
  static const String _helperName = r'_obfDecode$';

  final int xorKey;

  @override
  String get name => 'string_encrypt';

  @override
  void run(Component component, PassContext context) {
    // Find the first user library to inject our helper into.
    Library? targetLib;
    for (final lib in component.libraries) {
      if (context.shouldObfuscateLibrary(lib)) {
        targetLib = lib;
        break;
      }
    }
    if (targetLib == null) {
      return;
    }

    // Inject the _obfDecode$ helper and get the procedure.
    final decodeProcedure = _injectHelper(targetLib, component);

    // Walk the component and replace string literals.
    final transformer = StringEncryptTransformer(
      context: context,
      decodeProcedure: decodeProcedure,
      xorKey: xorKey,
    );
    component.transformChildren(transformer);
  }

  /// Inject the `_obfDecode$` procedure into [lib] and return it.
  ///
  /// Builds the kernel AST equivalent of:
  /// ```dart
  /// String _obfDecode$(List<int> bytes, int key) =>
  ///     String.fromCharCodes(bytes.map((b) => b ^ key));
  /// ```
  Procedure _injectHelper(Library lib, Component component) {
    // Resolve dart:core classes we need.
    final coreLib = component.libraries.firstWhere(
      (l) => l.importUri.toString() == 'dart:core',
    );
    final intClass = coreLib.classes.firstWhere((c) => c.name == 'int');
    final stringClass = coreLib.classes.firstWhere((c) => c.name == 'String');

    final intType = InterfaceType(intClass, Nullability.nonNullable);
    final stringType = InterfaceType(stringClass, Nullability.nonNullable);

    // Resolve Iterable class for map() return type.
    final iterableClass = coreLib.classes.firstWhere(
      (c) => c.name == 'Iterable',
    );
    final listClass = coreLib.classes.firstWhere((c) => c.name == 'List');
    final listIntType = InterfaceType(listClass, Nullability.nonNullable, [
      intType,
    ]);

    // Parameters: List<int> bytes, int key
    final bytesParam = VariableDeclaration('bytes', type: listIntType);
    final keyParam = VariableDeclaration('key', type: intType);

    // Build: (b) => b ^ key
    final bParam = VariableDeclaration('b', type: intType);

    // Resolve int.^ operator (int operator ^(int other))
    final xorMethod = intClass.procedures.firstWhere(
      (p) => p.name.text == '^',
    );
    final xorFunctionType = FunctionType(
      [intType],
      intType,
      Nullability.nonNullable,
    );

    // b ^ key
    final xorExpr = InstanceInvocation(
      InstanceAccessKind.Instance,
      VariableGet(bParam),
      Name('^'),
      Arguments([VariableGet(keyParam)]),
      interfaceTarget: xorMethod,
      functionType: xorFunctionType,
    );

    // Lambda: (b) => b ^ key
    final lambdaBody = ReturnStatement(xorExpr);
    final lambdaFunction = FunctionNode(
      lambdaBody,
      positionalParameters: [bParam],
      requiredParameterCount: 1,
      returnType: intType,
    );
    final lambda = FunctionExpression(lambdaFunction);

    // Resolve Iterable.map method
    final mapMethod = iterableClass.procedures.firstWhere(
      (p) => p.name.text == 'map',
    );

    // bytes.map((b) => b ^ key) — returns Iterable<int>
    final iterableIntType = InterfaceType(
      iterableClass,
      Nullability.nonNullable,
      [intType],
    );

    // Build the function type for map:
    // Iterable<int> Function(int Function(int))
    final mapCallFunctionType = FunctionType(
      [
        FunctionType([intType], intType, Nullability.nonNullable),
      ],
      iterableIntType,
      Nullability.nonNullable,
    );

    final mapCall = InstanceInvocation(
      InstanceAccessKind.Instance,
      VariableGet(bytesParam),
      Name('map'),
      Arguments([lambda]),
      interfaceTarget: mapMethod,
      functionType: mapCallFunctionType,
    );

    // Resolve String.fromCharCodes factory constructor
    final fromCharCodesConstructor = stringClass.procedures.firstWhere(
      (p) => p.name.text == 'fromCharCodes',
    );

    // String.fromCharCodes(bytes.map((b) => b ^ key))
    final fromCharCodesCall = StaticInvocation(
      fromCharCodesConstructor,
      Arguments([mapCall]),
    );

    // Build the full function body
    final body = ReturnStatement(fromCharCodesCall);
    final functionNode = FunctionNode(
      body,
      positionalParameters: [bytesParam, keyParam],
      requiredParameterCount: 2,
      returnType: stringType,
    );

    // Create the procedure.
    // Private names (starting with _) require a library reference.
    final procedure = Procedure(
      Name(_helperName, lib),
      ProcedureKind.Method,
      functionNode,
      fileUri: lib.fileUri,
      isStatic: true,
    );

    lib.addProcedure(procedure);
    return procedure;
  }

  List<int> encode(String s) {
    return utf8.encode(s).map((b) => b ^ xorKey).toList();
  }
}
