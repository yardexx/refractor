# spectrometer

Refractor's fixture-driven test harness for **developing** obfuscation passes.

A spectrometer splits light into a spectrum and takes a reading from each band.
This one does the same to an obfuscated build: it owns the build (compile →
obfuscate → compile, plus a plain baseline) and measures the result across
three independent **bands**.

| Band          | Question it answers                            | How |
|---------------|------------------------------------------------|-----|
| `correctness` | Does the pass survive the compiler?            | Kernel verifier gate + plain-vs-obfuscated behavioral equivalence on each target |
| `resistance`  | Did obfuscation actually happen in the binary? | Raw byte scan for denylist/allowlist, rename-map coverage, pass metric minimums |
| `impact`      | What did it cost?                              | Plain vs obfuscated binary size, size ratio, per-pass metrics |

Every band reports **readings** (sizes, counts) as well as pass/fail, so the
numbers are visible even on a green run.

## Running it

```bash
cd packages/spectrometer && dart test
```

`test/fixtures_test.dart` discovers every directory under `test/fixtures/` and
measures it, so **adding a fixture needs no test code**. CI runs this suite
alongside the root package's tests.

## Fixtures

Each scenario is one directory:

```text
test/fixtures/<name>/
  main.dart           # the program under obfuscation (dart: imports only)
  refractor.yaml      # the passes to apply
  expectations.yaml   # the contract for all three bands
```

Current fixtures:

- `rename/` — rename alone; distinctive identifiers must vanish.
- `string_encrypt/` — string encryption alone; secrets vanish, an excluded
  marker survives.
- `combined/` — both passes together on `exe`, `aot` and `jit`.

### `expectations.yaml`

One section per band. Every section and key is optional; unknown keys are
rejected, so a typo can't silently turn an assertion off.

```yaml
behavior:
  targets: [exe, aot, jit]     # default [exe]; correctness runs on each
  equivalent_to_plain: true    # default true: stdout must match a plain build
  verify_kernel: true          # default true: run the kernel verifier gate

resistance:
  denylist: [SecretAlgorithm]  # must NOT appear anywhere in the binary
  allowlist: [VISIBLE_MARKER]  # must still appear
  rename_helpers:              # originals the rename map must cover
    - SecretAlgorithm
  required_metrics:            # minimums, as <pass>.<metric>: <int>
    string_encrypt.strings_encrypted: 1

impact:
  max_size_ratio: 1.15         # optional; the ratio is always reported
```

The artifact scan is the primary resistance signal. The rename map and pass
metrics are sanity checks on the engine's own account of what it did.

**Every denylist entry must be present in the plain build.** The resistance
band scans the plain baseline too, and fails any entry the compiler already
dropped on its own: its absence after obfuscation would prove nothing. Small
members are easily inlined away by the AOT compiler, so fixtures keep the
identifiers under test alive with `@pragma('vm:never-inline')`. Plain field
names never survive AOT; check a `never-inline` getter instead, and leave the
field itself to `rename_helpers`.

### Conventions

- Prefer distinctive identifiers and literals over short generic tokens, so a
  denylist hit means a real leak and not an SDK coincidence.
- Mark each member under test `@pragma('vm:never-inline')` and avoid printing
  identifiers (such as `runtimeType`): stdout must match the plain build.
- Keep config exclusions minimal so the resistance check stays meaningful.
- Use `allowlist` for deliberately preserved markers, not as an escape hatch.
- Give each pass its own focused fixture; use `combined/` for interactions.

## Using it from code

```dart
import 'package:spectrometer/spectrometer.dart';
import 'package:test/test.dart';

void main() {
  test('my fixture', () async {
    final spectrum = await const Spectrometer().measureDir('path/to/fixture');
    expect(spectrum.ok, isTrue, reason: spectrum.describe());
  });
}
```

The harness is independent of `package:test`: bands return structured
`Spectrum` data, and the caller decides how to assert. The same data can drive
a CI summary or a standalone script.

## Why a separate package

Spectrometer depends on Refractor's internals (the concrete compiler, kernel
IO, config model and pass artifacts, via `package:refractor/testing.dart`)
because a tool that validates the engine has to reach into it. Isolating it in
its own `publish_to: none` package keeps that coupling explicit and out of
Refractor's own dependency surface. The coupling is deliberate: it should
break when internals shift.

## Status

Report-first by design. The impact band reports size and metrics rather than
enforcing baselines; `max_size_ratio` is the only optional assertion.
Regression baselines are deferred until the raw numbers are trusted, since
they are brittle across SDK bumps.
