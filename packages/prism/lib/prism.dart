/// prism — a source-free verifier for Refractor-obfuscated artifacts.
///
/// Point it at a built binary and the symbol map from that build; it scans the
/// artifact for the original identifiers the map says should be gone and
/// reports any that leaked. It reads only a binary and a JSON file, so it has
/// no dependency on the Refractor engine and no SDK pin — it is meant to drop
/// into a customer's CI as a post-build gate.
///
/// This is distinct from the internal `refractor_test_harness`, which builds
/// code itself to validate passes during development.
library;

export 'src/binary_scanner.dart';
export 'src/symbol_map.dart';
export 'src/verification.dart';
export 'src/verifier.dart';
