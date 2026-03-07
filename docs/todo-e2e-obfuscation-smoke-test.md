# TODO: End-to-End Obfuscation Smoke Test

Deferred follow-up from Tier 0.2/0.3 rename coverage work.

## Goal

Add one CLI-level integration test that verifies obfuscated output still runs correctly.

## Suggested Scope

- Build a small fixture package via the real CLI obfuscation flow.
- Execute the produced artifact.
- Assert expected runtime behavior/output.
- Keep fixture minimal but include:
  - static method/field usage (`StaticInvocation`, `StaticGet`, `StaticSet`)
  - constructor invocation paths (`ConstructorInvocation`, `SuperInitializer`, `RedirectingInitializer`)
  - at least one named constructor rename

## Why

Current pass-level tests are strong, but this catches wiring/regression issues in full pipeline execution.
