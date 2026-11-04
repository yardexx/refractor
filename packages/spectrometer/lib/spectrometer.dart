/// Spectrometer — Refractor's fixture-driven test harness.
///
/// A spectrometer splits light into a spectrum and takes a reading from each
/// band. This one does the same to an obfuscated build: it owns the build
/// (compile → obfuscate → compile, plus a plain baseline) and measures it
/// across independent bands:
///
///   * **correctness** — does the pass survive the compiler? (kernel verifier
///     gate + plain-vs-obfuscated behavioral equivalence)
///   * **resistance**  — did obfuscation actually happen in the shipped
///     binary? (raw byte scan for denylist/allowlist, rename map, metrics)
///   * **impact**      — what did it cost? (binary size, ratio, pass metrics)
///
/// It is engine-coupled and SDK-pinned by design: it reaches into Refractor
/// through `package:refractor/testing.dart` and should break when internals
/// shift.
///
/// It is intentionally independent of `package:test`: bands return structured
/// [Spectrum] data, and the caller decides how to assert on it.
library;

import 'package:spectrometer/src/spectrum.dart';

export 'src/bands/band.dart';
export 'src/bands/correctness_band.dart';
export 'src/bands/impact_band.dart';
export 'src/bands/resistance_band.dart';
export 'src/byte_scanner.dart';
export 'src/expectations.dart';
export 'src/fixture.dart';
export 'src/fixture_build.dart';
export 'src/spectrometer.dart';
export 'src/spectrum.dart';
