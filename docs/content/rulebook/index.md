---
title: Rulebook
description: What each obfuscation pass does to your code, in detail.
layout: docs
---

# Rulebook

The Rulebook documents **what each pass actually does to your code** and how to
tune it — the behavioural reference, as opposed to [Architecture](/architecture),
which explains how the machine is built.

A **pass** is one unit of obfuscation. Refractor runs the enabled passes in order
over your compiled program. The passes fall into three groups.

**Naming & data** — hide the identifiers and constants a reader keys off:

- [Rename](/rulebook/rename) — rewrites identifiers to short, meaningless names.
- [String encryption](/rulebook/string-encryption) — hides string literals behind a runtime decoder.
- [Integer encryption](/rulebook/int-encryption) — hides integer literals behind a runtime decoder.

**Expressions** — make the computations harder to read:

- [Arithmetic mangling](/rulebook/arithmetic-mangling) — rewrites `+`/`*` into equivalent, uglier expressions.

**Control flow** — obscure the shape of the program:

- [Opaque predicates](/rulebook/opaque-predicates) — entangles branch conditions with always-true predicates.
- [Control-flow flattening](/rulebook/control-flow-flatten) — turns a straight-line body into a switch state machine.
- [Dead code](/rulebook/dead-code) — inserts never-executed, opaquely-guarded junk.
- [Bogus control flow](/rulebook/bogus-control-flow) — wraps a body in an always-true branch over a real-looking clone.
- [Call indirection](/rulebook/call-indirection) — routes static calls through a never-inline forwarder.

## How to read a rule page

Every pass page follows the same shape, so you always know where to look — and it
doubles as the checklist for shipping a new pass:

1. **What it does** — the effect on your code, in one paragraph.
2. **What it targets** — which declarations/nodes it changes, and what it skips.
3. **Configuration** — the options and defaults.
4. **Scope & keep** — which keep mechanisms it honors (excludes, `@Refractor.keep()`, entry point).
5. **Guarantees & limitations** — what it promises, and what it explicitly does not.
6. **Output** — the report metrics and the artifact it writes.
7. **Example** — before and after.

<Info>
Obfuscation scope is always the current project — libraries matching your
`pubspec.yaml` package name and files under the working directory. External
packages and the SDK are never touched. See
[Policy](/architecture/policy) for the exact rule.
</Info>
