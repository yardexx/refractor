# prism

A source-free verifier that back-checks whether a built Dart artifact was
actually obfuscated. Point it at a finished binary — no source, no rebuild, no
dependency on the Refractor engine — and it reports what leaked. It is meant to
drop into CI as a post-build gate.

> **Status:** prism is not published yet (`publish_to: none`). Its own SDK
> floor is `>=3.5.0`, but inside this repository it resolves as part of the
> pub workspace, so it builds against the repo's pinned SDK. The "any modern
> Dart" promise only takes effect once it is released as a standalone package.

```bash
prism verify build/app.exe --map build/symbol_map.json
prism verify build/app.exe --policy prism.policy.yaml
prism verify build/app.exe --map build/symbol_map.json --policy prism.policy.yaml
```

At least one of `--map` / `--policy` is required. They are two independent
**bands**, folded into one verdict and exit code (`0` pass, `1` fail,
`64` usage error).

## Map band (`--map`)

Checks that the obfuscator did what it claimed. The oracle is the symbol map's
*originals*: every identifier renaming was supposed to erase. Any that still
appears verbatim is a leak, found with a **boundary-aware** scan (so `start`
does not match inside `restart`).

Leaks are tiered by confidence, because scanning a native binary works on
spellings, not scoped identities:

- **high** — distinctive originals; these gate the build.
- **low** — short or common names (`value`, `name`) that appear across any Dart
  binary; reported only.

`--fail-on high` (default) fails on high-confidence leaks; `any` fails on any
leak; `none` is report-only. `--min-length` tunes the distinctiveness cutoff.

## Policy band (`--policy`)

Checks the customer's *own* requirements — secrets, internal hostnames, markers
— which the symbol map cannot know. Needs no map, so it also covers string
encryption and hardcoded-secret hygiene.

```yaml
# prism.policy.yaml
assertions:
  - must_not_contain: ["renderer-secret", "vault-token"]
    severity: error
  - must_not_match: "sk_live_[A-Za-z0-9]+"   # secret-key shape
    severity: error
  - must_contain: ["main"]                    # entry point survived
    severity: warn
```

- `must_not_contain` / `must_contain` — literal substrings (raw, not
  boundary-aware: a secret is flagged wherever it appears).
- `must_not_match` — a regular expression; add `case_insensitive: true` to
  ignore case.
- `severity` — `error` (default, fails the run) or `warn` (reported only).

## Output

`--format text` (default) prints each band's findings and a verdict;
`--format json` emits a machine-readable report for CI to parse.

## Honest limits

prism scans bytes; it does not parse the program. It proves "no leaks found by
these probes," not "this binary is secure." Spelling collisions (a renamed name
that coincidentally matches a surviving one) are why low-confidence leaks exist.
Some originals survive obfuscation inherently — enum value names,
named-parameter labels, interface surfaces — and a future `kept` set in the
symbol map will let the map band classify those instead of flagging them.

## Relationship to the harness

prism is distinct from `refractor_test_harness`, the internal, engine-coupled
tool that *builds* code to validate passes during development. prism never
builds anything; it only reads an artifact and a map/policy.
