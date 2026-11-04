/// Prism — a fixture-driven harness that splits a Refractor build into a
/// spectrum of independently measurable bands.
///
/// A prism takes one build and decomposes it into bands you can inspect
/// separately:
///
///   * **correctness** — does the pass survive the compiler? (kernel verifier
///     gate + plain-vs-obfuscated behavioral equivalence)
///   * **resistance**  — did obfuscation actually happen in the shipped
///     binary? (`strings` denylist/allowlist + pass metrics)
///   * **impact**      — what did it cost? (binary size, ratio, pass metrics)
///
/// Prism is intentionally independent of `package:test`: bands return
/// structured Spectrum data, and the caller decides how to assert on it.
library;

export 'src/bands/band.dart';
export 'src/bands/correctness_band.dart';
export 'src/bands/impact_band.dart';
export 'src/bands/resistance_band.dart';
export 'src/expectations.dart';
export 'src/fixture.dart';
export 'src/fixture_build.dart';
export 'src/prism_runner.dart';
export 'src/spectrum.dart';
