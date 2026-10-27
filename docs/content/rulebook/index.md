---
title: Rulebook
description: What each obfuscation pass does to your code, in detail.
layout: docs
---

The Rulebook documents **what each pass actually does to your code** and how to
tune it — the behavioural reference, as opposed to [Architecture](/architecture),
which explains how the machine is built.

A **pass** is one unit of obfuscation. Refractor runs the enabled passes in order
over your compiled program. They fall into three groups: **naming & data** hides
the identifiers and constants a reader keys off, **expressions** make the
computations harder to read, and **control flow** obscures the shape of the
program.

<PassGrid />

## How to read a rule page

Every pass page follows the same shape, so you always know where to look — and it
doubles as the checklist for shipping a new pass:

1. **Facts** — the pass's group, its config key, whether the starter config turns it on, and which keep rules it honors.
2. **What it does** — the effect on your code, in one paragraph.
3. **Example** — before and after, side by side; switch the pass off and on to replay the change.
4. **What it targets** — which declarations/nodes it changes, and what it skips.
5. **Configuration** — a minimal setup and every option with its default.
6. **Scope & keep** — which keep mechanisms it honors (excludes, `@Refractor.keep()`, entry point).
7. **Guarantees & limitations** — what it promises, next to what it explicitly does not do.
8. **Output** — the report metrics and the artifact it writes.

<Info>
Obfuscation scope is always the current project — libraries matching your
`pubspec.yaml` package name and files under the working directory. External
packages and the SDK are never touched. See
[Policy](/architecture/policy) for the exact rule.
</Info>
