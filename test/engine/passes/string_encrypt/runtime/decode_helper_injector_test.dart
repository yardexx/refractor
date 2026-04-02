import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/passes/string_encrypt/runtime/decode_helper_injector.dart';
import 'package:refractor/src/policy/string_encrypt_policy_view.dart';
import 'package:test/test.dart';

import '../../../../helpers/kernel_helpers.dart';

void main() {
  group('DecodeHelperInjector', () {
    late Library coreLib;
    late Library convertLib;
    late Library firstUserLib;
    late Library secondUserLib;

    setUp(() {
      coreLib = makeDartCoreLibrary();
      convertLib = makeDartConvertLibrary();
      firstUserLib = makeUserLibrary('src/first.dart');
      secondUserLib = makeUserLibrary('src/second.dart');
    });

    DecodeHelperInjector makeInjector({
      StringEncryptPolicyView policy = const StringEncryptPolicyView(),
    }) {
      return DecodeHelperInjector(
        projectScope: makeProjectScope(),
        policy: policy,
      );
    }

    test('injects into the first eligible user library', () {
      final component = Component(
        libraries: [coreLib, convertLib, firstUserLib, secondUserLib],
      )..setMainMethodAndMode(null, true);

      final result = makeInjector().injectIntoFirstEligibleLibrary(component);

      expect(result, isNotNull);
      expect(result!.targetLibrary, same(firstUserLib));
      expect(
        firstUserLib.procedures.map((procedure) => procedure.name.text),
        contains(DecodeHelperInjector.helperBaseName),
      );
      expect(
        secondUserLib.procedures.map((procedure) => procedure.name.text),
        isNot(contains(DecodeHelperInjector.helperBaseName)),
      );
    });

    test('avoids helper-name collisions exactly as today', () {
      firstUserLib.addProcedure(
        Procedure(
          Name(DecodeHelperInjector.helperBaseName, firstUserLib),
          ProcedureKind.Method,
          FunctionNode(EmptyStatement()),
          fileUri: firstUserLib.fileUri,
          isStatic: true,
        ),
      );
      final component = Component(
        libraries: [coreLib, convertLib, firstUserLib],
      )..setMainMethodAndMode(null, true);

      final result = makeInjector().injectIntoFirstEligibleLibrary(component);

      expect(result, isNotNull);
      final helperNames = firstUserLib.procedures
          .map((procedure) => procedure.name.text)
          .toList();
      expect(helperNames, contains(DecodeHelperInjector.helperBaseName));
      expect(helperNames, contains('${DecodeHelperInjector.helperBaseName}1'));
      expect(
        result!.decodeProcedure.name.text,
        '${DecodeHelperInjector.helperBaseName}1',
      );
    });

    test('adds vm:never-inline pragma to injected helper', () {
      final component = Component(
        libraries: [coreLib, convertLib, firstUserLib],
      )..setMainMethodAndMode(null, true);

      final result = makeInjector().injectIntoFirstEligibleLibrary(component);

      expect(result, isNotNull);
      final annotation = result!.decodeProcedure.annotations.single;
      expect(annotation, isA<ConstantExpression>());
      final constant = (annotation as ConstantExpression).constant;
      expect(constant, isA<InstanceConstant>());
      final instance = constant as InstanceConstant;
      expect(instance.classNode.name, 'pragma');
      final nameField = instance.classNode.fields.firstWhere(
        (field) => field.name.text == 'name',
      );
      expect(
        instance.fieldValues[nameField.fieldReference],
        StringConstant('vm:never-inline'),
      );
    });

    test('keeps the injected helper static with the expected signature', () {
      final component = Component(
        libraries: [coreLib, convertLib, firstUserLib],
      )..setMainMethodAndMode(null, true);

      final result = makeInjector().injectIntoFirstEligibleLibrary(component);

      expect(result, isNotNull);
      final helper = result!.decodeProcedure;
      expect(helper.isStatic, isTrue);
      expect(helper.function.requiredParameterCount, 2);
      expect(helper.function.positionalParameters, hasLength(2));
      expect(helper.function.returnType, isA<InterfaceType>());

      final bytesType =
          helper.function.positionalParameters.first.type as InterfaceType;
      final keyType =
          helper.function.positionalParameters.last.type as InterfaceType;
      final returnType = helper.function.returnType as InterfaceType;

      expect(bytesType.classNode.name, 'List');
      expect(bytesType.typeArguments.single, isA<InterfaceType>());
      expect(
        (bytesType.typeArguments.single as InterfaceType).classNode.name,
        'int',
      );
      expect(keyType.classNode.name, 'int');
      expect(returnType.classNode.name, 'String');
    });
  });
}
