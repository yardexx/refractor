/// Internal-facing surface for first-party test harnesses
/// (`refractor_test_harness`).
///
/// These symbols are implementation details of Refractor that test tooling
/// legitimately needs: concrete IO-layer compiler/kernel implementations and
/// the config model. They are intentionally kept out of the main
/// `package:refractor/refractor.dart` barrel so they are not part of the
/// supported public API — harnesses opt in through this library and accept
/// that it may change with internal refactors.
library;

export 'src/config/model/refractor_config.dart' show RefractorConfig;
export 'src/engine/compiler/dart_compiler.dart' show DartCompiler;
export 'src/engine/kernel/file_kernel_io.dart' show FileKernelIO;
