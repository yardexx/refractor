import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/string_encrypt/runtime/string_encrypt_setup_result.dart';
import 'package:refractor/src/policy/string_encrypt_policy_view.dart';
import 'package:refractor/src/project/project_scope.dart';

final class DecodeHelperInjector {
  DecodeHelperInjector({
    required ProjectScope projectScope,
    required StringEncryptPolicyView policy,
  }) : _projectScope = projectScope,
       _policy = policy;

  static const String helperBaseName = r'_obfDecode$';

  final ProjectScope _projectScope;
  final StringEncryptPolicyView _policy;

  StringEncryptSetupResult? injectIntoFirstEligibleLibrary(
    Component component,
  ) {
    final targetLibrary = _findFirstEligibleLibrary(component);
    if (targetLibrary == null) {
      return null;
    }

    final context = _DecodeHelperKernelContext.resolve(component);
    final procedure = _DecodeHelperBuilder(
      library: targetLibrary,
      context: context,
    ).buildProcedure();

    targetLibrary.addProcedure(procedure);
    return StringEncryptSetupResult(
      targetLibrary: targetLibrary,
      decodeProcedure: procedure,
    );
  }

  Library? _findFirstEligibleLibrary(Component component) {
    for (final library in component.libraries) {
      if (_projectScope.containsLibrary(library) &&
          !_policy.isLibraryKept(library)) {
        return library;
      }
    }
    return null;
  }
}

final class _DecodeHelperBuilder {
  _DecodeHelperBuilder({
    required this.library,
    required this.context,
  });

  final Library library;
  final _DecodeHelperKernelContext context;

  late final VariableDeclaration _bytesParam = VariableDeclaration(
    'bytes',
    type: context.listIntType,
  );
  late final VariableDeclaration _keyParam = VariableDeclaration(
    'key',
    type: context.intType,
  );
  late final VariableDeclaration _shiftVar = VariableDeclaration(
    'shift',
    type: context.intType,
    initializer: IntLiteral(0),
  );

  Procedure buildProcedure() {
    return Procedure(
      Name(_freshHelperName(), library),
      ProcedureKind.Method,
      FunctionNode(
        Block([
          _shiftVar,
          ReturnStatement(_buildDecodeReturnExpression()),
        ]),
        positionalParameters: [_bytesParam, _keyParam],
        requiredParameterCount: 2,
        returnType: context.stringType,
      ),
      fileUri: library.fileUri,
      isStatic: true,
    )..addAnnotation(_buildNeverInlineAnnotation());
  }

  // String _obfDecode$(List<int> bytes, int key) {
  //   var shift = 0;
  //   return Utf8Codec().decode(List<int>.of(bytes.reversed.map((byte) {
  //     final decoded = byte ^ ((key >> shift) & 0xFF);
  //     shift = (shift + 8) & 24;
  //     return decoded;
  //   })));
  // }
  Expression _buildDecodeReturnExpression() {
    final mappedBytes = _buildMappedDecodedBytes();
    final byteList = StaticInvocation(
      context.listOfFactory,
      Arguments([mappedBytes], types: [context.intType]),
    );

    return InstanceInvocation(
      InstanceAccessKind.Instance,
      ConstructorInvocation(
        context.utf8CodecConstructor,
        Arguments.empty(),
      ),
      Name('decode'),
      Arguments([byteList]),
      interfaceTarget: context.decodeMethod,
      functionType: FunctionType(
        [context.listIntType],
        context.stringType,
        Nullability.nonNullable,
      ),
    );
  }

  // bytes.reversed.map((byte) {
  //   final decoded = byte ^ ((key >> shift) & 0xFF);
  //   shift = (shift + 8) & 24;
  //   return decoded;
  // })
  Expression _buildMappedDecodedBytes() {
    final reversedBytes = InstanceGet(
      InstanceAccessKind.Instance,
      VariableGet(_bytesParam),
      Name('reversed'),
      interfaceTarget: context.reversedGetter,
      resultType: context.iterableIntType,
    );

    return InstanceInvocation(
      InstanceAccessKind.Instance,
      reversedBytes,
      Name('map'),
      Arguments(
        [_buildDecodeMapLambda()],
        types: [context.intType],
      ),
      interfaceTarget: context.mapMethod,
      functionType: FunctionType(
        [
          FunctionType(
            [context.intType],
            context.intType,
            Nullability.nonNullable,
          ),
        ],
        context.iterableIntType,
        Nullability.nonNullable,
      ),
    );
  }

  // (byte) {
  //   final decoded = byte ^ ((key >> shift) & 0xFF);
  //   shift = (shift + 8) & 24;
  //   return decoded;
  // }
  Expression _buildDecodeMapLambda() {
    final byteParam = VariableDeclaration('byte', type: context.intType);
    final decodedVar = VariableDeclaration(
      'decoded',
      type: context.intType,
      initializer: _buildDecodedByteExpression(byteParam),
    );

    return FunctionExpression(
      FunctionNode(
        Block([
          decodedVar,
          _buildShiftUpdateStatement(),
          ReturnStatement(VariableGet(decodedVar)),
        ]),
        positionalParameters: [byteParam],
        requiredParameterCount: 1,
        returnType: context.intType,
      ),
    );
  }

  // byte ^ ((key >> shift) & 0xFF)
  Expression _buildDecodedByteExpression(VariableDeclaration byteParam) {
    final shiftedKey = _buildIntInvocation(
      receiver: VariableGet(_keyParam),
      methodName: '>>',
      argument: VariableGet(_shiftVar),
      target: context.shiftRightMethod,
    );
    final maskedKeyByte = _buildIntInvocation(
      receiver: shiftedKey,
      methodName: '&',
      argument: IntLiteral(0xFF),
      target: context.bitAndMethod,
    );

    return _buildIntInvocation(
      receiver: VariableGet(byteParam),
      methodName: '^',
      argument: maskedKeyByte,
      target: context.xorMethod,
    );
  }

  // shift = (shift + 8) & 24;
  Statement _buildShiftUpdateStatement() {
    final advancedShift = _buildIntInvocation(
      receiver: VariableGet(_shiftVar),
      methodName: '+',
      argument: IntLiteral(8),
      target: context.addMethod,
    );

    return ExpressionStatement(
      VariableSet(
        _shiftVar,
        _buildIntInvocation(
          receiver: advancedShift,
          methodName: '&',
          argument: IntLiteral(24),
          target: context.bitAndMethod,
        ),
      ),
    );
  }

  ConstantExpression _buildNeverInlineAnnotation() {
    return ConstantExpression(
      InstanceConstant(
        context.pragmaClass.reference,
        const [],
        <Reference, Constant>{
          context.pragmaNameField.fieldReference: StringConstant(
            'vm:never-inline',
          ),
          context.pragmaOptionsField.fieldReference: NullConstant(),
        },
      ),
    );
  }

  InstanceInvocation _buildIntInvocation({
    required Expression receiver,
    required String methodName,
    required Expression argument,
    required Procedure target,
  }) {
    return InstanceInvocation(
      InstanceAccessKind.Instance,
      receiver,
      Name(methodName),
      Arguments([argument]),
      interfaceTarget: target,
      functionType: FunctionType(
        [context.intType],
        context.intType,
        Nullability.nonNullable,
      ),
    );
  }

  String _freshHelperName() {
    final usedNames = <String>{
      for (final procedure in library.procedures) procedure.name.text,
      for (final field in library.fields) field.name.text,
    };

    if (!usedNames.contains(DecodeHelperInjector.helperBaseName)) {
      return DecodeHelperInjector.helperBaseName;
    }

    var suffix = 1;
    while (usedNames.contains(
      '${DecodeHelperInjector.helperBaseName}$suffix',
    )) {
      suffix++;
    }
    return '${DecodeHelperInjector.helperBaseName}$suffix';
  }
}

final class _DecodeHelperKernelContext {
  const _DecodeHelperKernelContext({
    required this.intType,
    required this.stringType,
    required this.iterableIntType,
    required this.listIntType,
    required this.shiftRightMethod,
    required this.bitAndMethod,
    required this.xorMethod,
    required this.addMethod,
    required this.reversedGetter,
    required this.mapMethod,
    required this.listOfFactory,
    required this.decodeMethod,
    required this.utf8CodecConstructor,
    required this.pragmaClass,
    required this.pragmaNameField,
    required this.pragmaOptionsField,
  });

  factory _DecodeHelperKernelContext.resolve(Component component) {
    final coreLibrary = component.libraries.firstWhere(
      (candidate) => candidate.importUri.toString() == 'dart:core',
    );
    final convertLibrary = component.libraries.firstWhere(
      (candidate) => candidate.importUri.toString() == 'dart:convert',
    );
    final intClass = coreLibrary.classes.firstWhere((cls) => cls.name == 'int');
    final numClass = coreLibrary.classes.firstWhere((cls) => cls.name == 'num');
    final stringClass = coreLibrary.classes.firstWhere(
      (cls) => cls.name == 'String',
    );
    final iterableClass = coreLibrary.classes.firstWhere(
      (cls) => cls.name == 'Iterable',
    );
    final listClass = coreLibrary.classes.firstWhere(
      (cls) => cls.name == 'List',
    );
    final pragmaClass = coreLibrary.classes.firstWhere(
      (cls) => cls.name == 'pragma',
    );
    final utf8CodecClass = convertLibrary.classes.firstWhere(
      (cls) => cls.name == 'Utf8Codec',
    );

    final intType = InterfaceType(intClass, Nullability.nonNullable);

    return _DecodeHelperKernelContext(
      intType: intType,
      stringType: InterfaceType(stringClass, Nullability.nonNullable),
      iterableIntType: InterfaceType(
        iterableClass,
        Nullability.nonNullable,
        [intType],
      ),
      listIntType: InterfaceType(listClass, Nullability.nonNullable, [intType]),
      shiftRightMethod: intClass.procedures.firstWhere(
        (procedure) => procedure.name.text == '>>',
      ),
      bitAndMethod: intClass.procedures.firstWhere(
        (procedure) => procedure.name.text == '&',
      ),
      xorMethod: intClass.procedures.firstWhere(
        (procedure) => procedure.name.text == '^',
      ),
      addMethod: numClass.procedures.firstWhere(
        (procedure) => procedure.name.text == '+',
      ),
      reversedGetter: listClass.procedures.firstWhere(
        (procedure) => procedure.name.text == 'reversed',
      ),
      mapMethod: iterableClass.procedures.firstWhere(
        (procedure) => procedure.name.text == 'map',
      ),
      listOfFactory: listClass.procedures.firstWhere(
        (procedure) => procedure.name.text == 'of',
      ),
      decodeMethod: utf8CodecClass.procedures.firstWhere(
        (procedure) => procedure.name.text == 'decode',
      ),
      utf8CodecConstructor: utf8CodecClass.constructors.single,
      pragmaClass: pragmaClass,
      pragmaNameField: pragmaClass.fields.firstWhere(
        (field) => field.name.text == 'name',
      ),
      pragmaOptionsField: pragmaClass.fields.firstWhere(
        (field) => field.name.text == 'options',
      ),
    );
  }

  final InterfaceType intType;
  final InterfaceType stringType;
  final InterfaceType iterableIntType;
  final InterfaceType listIntType;
  final Procedure shiftRightMethod;
  final Procedure bitAndMethod;
  final Procedure xorMethod;
  final Procedure addMethod;
  final Procedure reversedGetter;
  final Procedure mapMethod;
  final Procedure listOfFactory;
  final Procedure decodeMethod;
  final Constructor utf8CodecConstructor;
  final Class pragmaClass;
  final Field pragmaNameField;
  final Field pragmaOptionsField;
}
