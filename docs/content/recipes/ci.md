---
title: Continuous integration
description: Run Refractor in CI and read its build report.
layout: docs
---

Refractor needs no special setup to run in CI. Every build prints a plain-text
report of the passes that ran, what they changed, and any failures. In GitHub
Actions it also writes a Markdown version of the report to
`GITHUB_STEP_SUMMARY`, so it appears in the job summary without any extra flags.

If any pass fails, the build exits with a non-zero code and writes no output, so
a broken obfuscation fails the job instead of slipping through.

A minimal setup is two steps:

```yaml
- run: dart pub global activate --source git https://github.com/yardexx/refractor.git
- run: refractor build --target exe
```

Keep the symbol map from every release build. Upload `build/symbol_map.json` as a
CI artifact named after the version, so you can
[symbolicate](/recipes/symbolication) crash reports from that release later. Keep
it private and out of the release itself, since it undoes the renaming.

<Info>

Pin the Dart SDK version in CI. Refractor's bundled kernel library only works
with one SDK version; see [SDK compatibility](/guide#sdk-compatibility).

</Info>
