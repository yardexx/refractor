import 'package:kernel/kernel.dart';

abstract class KernelIO {
  /// Load a kernel [Component] from a `.dill` file at [path].
  Component load(String path);

  /// Write a kernel [Component] to a `.dill` file at [path].
  void write(Component component, String path);
}
