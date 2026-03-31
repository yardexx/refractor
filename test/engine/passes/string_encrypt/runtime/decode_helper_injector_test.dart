import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/passes/string_encrypt/runtime/decode_helper_injector.dart';
import 'package:refractor/src/policy/string_encrypt_policy_view.dart';
import 'package:test/test.dart';

import '../../../../helpers/kernel_helpers.dart';

void main() {
  group('DecodeHelperInjector', () {
    late Library coreLib;
    late Library firstUserLib;
    late Library secondUserLib;

    setUp(() {
      coreLib = makeDartCoreLibrary();
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
        libraries: [coreLib, firstUserLib, secondUserLib],
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
        libraries: [coreLib, firstUserLib],
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
  });
}
