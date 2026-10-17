---
title: Flutter apps
description: Notes on obfuscating a Flutter build with Refractor.
layout: docs
---

# Flutter apps

Refractor operates on a Dart kernel entrypoint. Flutter's build pipeline produces
kernel differently from `dart compile`, so first-class Flutter integration is
still being worked out.

What already carries over:

- **External overrides are preserved.** The rename pass detects members that
  override framework types (`build`, `==`, `hashCode`, …) and leaves their names
  intact, so widget dispatch keeps working. See
  [Rename](/rulebook/rename).
- **Keep your public API** with `@Refractor.keep()` or `exclude` globs — useful
  for plugin surfaces and anything reached via reflection or platform channels.

<Info>
This recipe is a work in progress. If you're wiring Refractor into a Flutter
build, please share your setup in an issue so we can document a supported path.
</Info>
