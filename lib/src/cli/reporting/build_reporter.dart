import 'package:refractor/src/engine/engine.dart';

abstract class BuildReporter {
  String render(BuildResult result);
}
