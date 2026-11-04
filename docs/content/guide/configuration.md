---
title: Configuration
description: The refractor.yaml reference.
layout: docs
---

# Configuration

Create a `refractor.yaml` in your project root. The file is required — Refractor
fails fast if it is missing, empty, or malformed, and rejects unknown keys.

Obfuscation scope is always the current project: libraries matching the `name` in
`pubspec.yaml` and files under the working directory.

```yaml
refractor:
  # Path for the build-artifacts JSON (per-pass report: rename symbol map,
  # string-encryption records).
  artifact_json: build_artifacts.json

  # Path for the versioned symbol map used by `refractor symbolicate`.
  symbol_map: symbol_map.json

  # Library path exclusions (glob). Keeps whole libraries.
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"

  # Detailed logging (same as the --verbose flag).
  verbose: false

  passes:
    # Naming & data
    rename:
      enabled: true
      # exclude:
      #   - "lib/src/public_api/**"
      # seed: 1337          # deterministic names for reproducible builds
    string_encrypt:
      enabled: true
      # seed: 0x5A          # PRNG seed; each literal still gets its own key
      # exclude_patterns:   # regexes matched against literal *values*
      #   - "^https://"
    int_encrypt:
      enabled: true
      # seed: 0x1F
      # min_magnitude: 2    # leave |value| < 2 (-1, 0, 1) inline

    # Expressions
    arithmetic_mangle: true

    # Control flow
    opaque_predicate: true
    control_flow_flatten: true
    dead_code: true
    bogus_control_flow:
      enabled: true
      # max_statements: 16  # cloning doubles the body; larger ones are skipped
    call_indirection: true
```

Each pass value under `refractor.passes` can be `true` (enabled with defaults),
`false` (disabled), or a map of pass-specific options.

## Global settings (`refractor:`)

| Key | Type | Default | Meaning |
|---|---|---|---|
| `artifact_json` | string | `build_artifacts.json` | Output path for the pass-artifacts JSON (rename symbol map, string records). |
| `symbol_map` | string | `symbol_map.json` | Output path for the versioned symbol map (relative paths resolve under `build/`). Written when rename produces a mapping; consumed by [`symbolicate`](/guide/commands#refractor-symbolicate-trace-file). |
| `exclude` | list of glob | `[]` | Libraries to leave untouched by every pass. |
| `verbose` | bool | `false` | Enable detailed logging. |

## Pass options

A pass value can be `true` (enabled with defaults), `false` (disabled), or a map.
**Every** pass accepts `enabled` (bool) and `exclude` (glob list — extra
libraries this pass leaves alone). The options beyond those:

| Pass | Option | Default | Meaning |
|---|---|---|---|
| `rename` | `seed` (int) | — | Deterministic obfuscated names for reproducible builds. |
| `string_encrypt` | `seed` (int) | `0x5A` | Seeds the per-literal key PRNG (not a single fixed key). |
| `string_encrypt` | `exclude_patterns` (regex list) | `[]` | Literal values matching any pattern stay in plaintext. |
| `int_encrypt` | `seed` (int) | `0x1F` | Seeds the per-literal key PRNG. |
| `int_encrypt` | `min_magnitude` (int) | `2` | Literals with `|value|` below this stay inline. |
| `opaque_predicate` | `seed` (int) | `0x05A1` | Seeds per-site template and variable selection. |
| `arithmetic_mangle` | `seed` (int) | `0x0A17` | Seeds the identity/constant choices. |
| `control_flow_flatten` | `seed` (int) | `0x0CFF` | Seeds the per-function case layout. |
| `dead_code` | `seed` (int) | `0x0DEAD` | Seeds the guard site and junk constants. |
| `bogus_control_flow` | `seed` (int) | `0x3D` | Seeds the guard-parameter choice. |
| `bogus_control_flow` | `max_statements` (int) | `16` | Only wrap bodies up to this many top-level statements. |
| `call_indirection` | — | — | No options beyond `enabled`/`exclude`. |

See the [Rulebook](/rulebook) for what each pass does and its full behaviour.

## Keeping declarations

Beyond glob `exclude`, mark individual declarations to preserve with the
`@Refractor.keep()` annotation from the `refractor_annotation` package:

```dart
import 'package:refractor_annotation/refractor_annotation.dart';

@Refractor.keep()
class PublicApi {}
```
