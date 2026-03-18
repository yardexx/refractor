import 'package:args/args.dart';
import 'package:app/main.dart';

const String version = '0.0.1';

ArgParser buildParser() {
  return ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information.',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Show additional command output.',
    )
    ..addFlag('version', negatable: false, help: 'Print the tool version.');
}

void printUsage(ArgParser argParser) {
  print('Usage: dart app.dart <flags> [arguments]');
  print(argParser.usage);
}

Future<void> main(List<String> arguments) async {
  final ArgParser argParser = buildParser();
  try {
    final ArgResults results = argParser.parse(arguments);
    bool verbose = false;

    // Process the parsed arguments.
    if (results.flag('help')) {
      printUsage(argParser);
      return;
    }
    if (results.flag('version')) {
      print('example version: $version');
      return;
    }
    if (results.flag('verbose')) {
      verbose = true;
    }

    final lines = await runExampleApp(verbose: verbose);
    for (final line in lines) {
      print(line);
    }

    if (results.rest.isNotEmpty) {
      print('Positional arguments: ${results.rest.join(', ')}');
    }
    if (verbose) {
      print('[VERBOSE] All arguments: ${results.arguments.join(' ')}');
    }
  } on FormatException catch (e) {
    // Print usage information if an invalid argument was provided.
    print(e.message);
    print('');
    printUsage(argParser);
  }
}
