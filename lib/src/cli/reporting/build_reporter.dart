import 'package:refractor/src/engine/engine.dart';

abstract class BuildReporter {
  void report(BuildResult result);
}
