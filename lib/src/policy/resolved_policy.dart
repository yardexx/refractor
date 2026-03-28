import 'package:refractor/src/policy/rename_policy_view.dart';
import 'package:refractor/src/policy/string_encrypt_policy_view.dart';

final class ResolvedPolicy {
  const ResolvedPolicy({
    required this.rename,
    required this.stringEncrypt,
  });

  final RenamePolicyView rename;
  final StringEncryptPolicyView stringEncrypt;
}
