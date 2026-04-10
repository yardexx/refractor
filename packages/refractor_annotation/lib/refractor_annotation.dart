/// Lightweight annotations for controlling Refractor behavior in source code.
///
/// Import this package from application code when you want to mark symbols for
/// Refractor-aware tooling without depending on the Refractor CLI package.
///
/// The first shipped annotation surface is intentionally narrow:
///
/// ```dart
/// import 'package:refractor_annotation/refractor_annotation.dart';
///
/// @Refractor.keep()
/// class PublicApi {}
/// ```
///
/// In `refractor` `0.2.2`, `@Refractor.keep()` is consumed by the rename pass.
library;

export 'src/refractor.dart';
