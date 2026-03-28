import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/pass/selection/pass_selection.dart';

abstract interface class PassSelector<S extends PassSelection> {
  S select(Component component);
}
