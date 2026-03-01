import 'dart:io';

import 'package:refractor/src/cli/command_runner.dart';

Future<void> main(List<String> args) async {
  final exitCode = await RefractorCommandRunner().run(args);
  exit(exitCode);
}
