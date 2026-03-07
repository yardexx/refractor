import 'package:json_annotation/json_annotation.dart';

part 'pass_config.g.dart';
part 'rename_pass_config.dart';
part 'string_encrypt_pass_config.dart';

sealed class PassConfig {
  PassConfig({this.enabled = true});

  final bool enabled;
}
