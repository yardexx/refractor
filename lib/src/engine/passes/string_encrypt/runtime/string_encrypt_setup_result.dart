import 'package:kernel/ast.dart';

final class StringEncryptSetupResult {
  const StringEncryptSetupResult({
    required this.targetLibrary,
    required this.decodeProcedure,
  });

  final Library targetLibrary;
  final Procedure decodeProcedure;
}
