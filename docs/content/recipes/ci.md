---
title: Continuous integration
description: Run Refractor in CI and read its build report.
layout: docs
---

# Continuous integration

Refractor is CI-friendly out of the box.

- Every build prints a plain-text report of the passes that ran, their metrics,
  and any failures.
- When running in **GitHub Actions**, Refractor also appends a Markdown summary
  to `GITHUB_STEP_SUMMARY`, so the run shows up in the job summary automatically —
  no extra flags.
- A build where any pass fails exits non-zero and emits **no output**, so a
  broken obfuscation can't slip through green.
- Archive the **symbol map** from each release build: upload
  `build/symbol_map.json` as a CI artifact, keyed by version, so you can
  [symbolicate](/recipes/symbolication) crash reports later. Keep it private —
  don't attach it to the released binary.

A minimal step:

```yaml
- run: dart pub global activate --source git https://github.com/yardexx/refractor.git
- run: refractor build --target exe
```

<Info>

Pin the Dart SDK your project expects — Refractor's vendored kernel is tied to a
specific SDK line (see [SDK compatibility](/guide#sdk-compatibility)).

</Info>
