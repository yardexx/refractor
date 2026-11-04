/// The internal, fixture-driven harness for *developing* Refractor's passes.
///
/// It owns the build (compile → obfuscate → compile) and decomposes the
/// result into independently measurable bands:
///
///   * **correctness** — does the pass survive the compiler? (kernel verifier
///     gate + plain-vs-obfuscated behavioral equivalence)
///   * **resistance**  — did obfuscation actually happen in the shipped
///     binary? (`strings` denylist/allowlist + pass metrics)
///   * **impact**      — what did it cost? (binary size, ratio, pass metrics)
///
/// This is distinct from `prism`, the source-free, customer-facing verifier
/// that inspects an already-built artifact. The harness is engine-coupled and
/// SDK-pinned by design; the verifier is not.
///
/// The harness is intentionally independent of `package:test`: bands return
/// structured Spectrum data, and the caller decides how to assert on it.
library;

export 'src/bands/band.dart';
export 'src/bands/correctness_band.dart';
export 'src/bands/impact_band.dart';
export 'src/bands/resistance_band.dart';
export 'src/expectations.dart';
export 'src/fixture.dart';
export 'src/fixture_build.dart';
export 'src/harness_runner.dart';
export 'src/spectrum.dart';
