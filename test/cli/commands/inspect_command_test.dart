import 'package:args/command_runner.dart';
import 'package:refractor/src/cli/commands/inspect_command.dart';
import 'package:test/test.dart';

void main() {
  group('InspectCommand', () {
    test('throws UsageException when <path.dill> is missing', () async {
      final runner = CommandRunner<int>('test', 'test')
        ..addCommand(InspectCommand());

      await expectLater(
        runner.run(['inspect']),
        throwsA(isA<UsageException>()),
      );
    });
  });
}
