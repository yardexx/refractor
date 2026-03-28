# Resistance Test Fixtures

This folder contains the fixture-based mini-framework used by
`test/e2e/strings_resistance_test.dart`.

## What It Tests

The current resistance tests validate the final native executable produced by
`RefractorEngine` with `Target.exe`.

For each fixture, the test harness:

1. loads `main.dart`, `refractor.yaml`, and `expectations.yaml`
2. builds the fixture through the normal engine pipeline
3. locates `strings` on `PATH`
4. runs `strings` on the produced executable
5. normalizes the output to non-empty trimmed lines
6. applies pass-specific assertions from `expectations.yaml`

Artifact-level leakage checks are the primary assertion. Helper signals such as
rename mappings or pass metrics are secondary diagnostics only.

## Fixture Layout

Each pass-specific scenario lives in its own folder:

```text
test/fixtures/resistance/<fixture>/
  main.dart
  refractor.yaml
  expectations.yaml
```

Current fixtures:

- `rename/`
- `string_encrypt/`

This keeps expectations localized to the pass behavior under test and avoids
one shared fixture accumulating unrelated assertions.

## expectations.yaml Schema

The test-only schema is intentionally small:

- `denylist`: strings that must not appear in normalized `strings` output
- `allowlist`: strings that are expected to remain visible
- `rename_helpers`: original identifiers that should have an obfuscated entry in
  `BuildResult.symbolTable`
- `required_metrics`: minimum metric values in `<pass>.<metric>: <int>` format

Example:

```yaml
denylist:
  - SecretAlgorithm
allowlist:
  - VISIBLE_MARKER
rename_helpers:
  - processConfidentialData
required_metrics:
  string_encrypt.strings_encrypted: 1
```

## Current Conventions

- Keep fixture source and expectations easy to grep.
- Prefer distinctive identifiers and literals over short generic tokens.
- Keep config exclusions minimal so the resistance check stays meaningful.
- Use `allowlist` for deliberate preserved markers or tolerated values, not as a
  broad escape hatch.
- For `rename`, focus the first fixtures on externally visible identifiers.
- For `string_encrypt`, use pass metrics only as a sanity signal alongside the
  real artifact scan.

## Adding A New Fixture

1. Create `test/fixtures/resistance/<name>/`.
2. Add `main.dart` with a focused scenario.
3. Add `refractor.yaml` enabling the pass behavior you want to validate.
4. Add `expectations.yaml` with denylist/allowlist/helper expectations.
5. Extend `test/e2e/strings_resistance_test.dart` with a dedicated test case.

If a future pass makes a resistance claim but `strings` is not the right tool,
keep the same fixture-driven shape but add a different artifact probe instead of
forcing everything through the current `strings` flow.
