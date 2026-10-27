---
layout: docs
---

# Refractor

Refractor is an obfuscation tool for Dart code. It applies obfuscation directly
at the kernel bytecode level.

<Warning>
Refractor is in early development. Real impact on the generated binary may vary.
</Warning>

Ready to try it? The [Quickstart](/guide/quickstart) takes you from install to an
obfuscated binary in a few minutes.

## How it works

Refractor sits between the Dart compiler and your final binary. It compiles your
entrypoint to a kernel (`.dill`) file, rewrites that program in memory, and then
compiles the result to a native executable, an AOT or JIT snapshot, or back to
kernel. Your source code is never modified.

Working on kernel rather than source is what makes the transforms safe. By the
time Refractor sees your program, the Dart front end has already resolved every
type, call target and override, so a renamed method is renamed everywhere it is
used, and a member that overrides a framework type keeps its name. The
[Architecture](/architecture) section covers the pipeline in depth.

## What it does

Refractor runs a configurable set of **obfuscation passes** over your compiled
program — see the [Rulebook](/rulebook) for exactly what each one does:

- **Naming & data** — rename identifiers, and encrypt string and integer
  literals behind injected runtime decoders.
- **Expressions** — mangle integer arithmetic into equivalent, uglier forms.
- **Control flow** — opaque predicates, control-flow flattening, dead code,
  bogus branches, and call indirection.

When the rename pass runs, the build also writes a versioned `symbol_map.json`, and
[`refractor symbolicate`](/recipes/symbolication) uses it to turn an obfuscated
stack trace back into original names. Each run ends with a build report of what
every pass changed, which also lands in the job summary when you run in GitHub
Actions.

## SDK compatibility

Refractor is pinned to one Dart SDK line at a time, because the vendored kernel
API and binary format are tied to a specific SDK snapshot. This release expects
Dart **3.11.3**.

## Next steps

- [Quickstart](/guide/quickstart) — install Refractor and obfuscate your first build.
- [Commands](/guide/commands) — `build`, `symbolicate`, `inspect`, `init`, and the global `--verbose`.
- [Configuration](/guide/configuration) — the `refractor.yaml` reference.
- [Architecture](/architecture) — how Refractor is built, end to end.

## Project & license

Refractor is open source at
[github.com/yardexx/refractor](https://github.com/yardexx/refractor); issues and
contributions are welcome. See the repository's `LICENSE` file for licensing
terms.
