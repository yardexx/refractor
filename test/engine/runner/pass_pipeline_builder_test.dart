import 'package:refractor/src/config/model/pass_config.dart';
import 'package:refractor/src/engine/passes/rename/rename_pass.dart';
import 'package:refractor/src/engine/passes/string_encrypt/string_encrypt_pass.dart';
import 'package:refractor/src/engine/runner/pass_pipeline_builder.dart';
import 'package:test/test.dart';

void main() {
  group('PassPipelineBuilder', () {
    test('preserves input order', () {
      final builder = PassPipelineBuilder();

      final passes = builder.build([
        StringEncryptPassConfig(),
        RenamePassConfig(),
      ]);

      expect(passes[0], isA<StringEncryptPass>());
      expect(passes[1], isA<RenamePass>());
      expect(passes.map((pass) => pass.name).toList(), [
        'string_encrypt',
        'rename',
      ]);
    });
  });
}
