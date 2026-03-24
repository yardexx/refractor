import 'package:refractor/src/config/model/pass_config.dart';
import 'package:refractor/src/engine/passes.dart';
import 'package:refractor/src/engine/pipeline_builder.dart';
import 'package:test/test.dart';

void main() {
  group('PassPipelineBuilder', () {
    test('preserves input order', () {
      final builder = PipelineBuilder();

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
