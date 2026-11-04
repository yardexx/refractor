---
title: Architecture Overview
description: How Refractor is structured — layers, blocks, and the pipeline.
layout: docs
---

# Architecture

Refractor is a Dart **kernel-level** obfuscator. It does not touch your source:
it compiles your entrypoint to Dart's intermediate representation (a `.dill`
kernel file), rewrites that AST in memory, writes it back, and compiles the
result to the final binary.

```
dart compile kernel   →   load .dill (Component)   →   obfuscation passes
      (source → IR)              (IR → AST)               (mutate the AST)
                                                                │
   final binary   ←   dart compile exe/aot/jit   ←   write .dill
```

Working at the kernel level is the central design choice: the front end has
already resolved types, interface targets, canonical names, and override
relationships — exactly the information that makes correct renaming tractable.
That is also why the passes are deliberately coupled to `package:kernel` (see
[kernel_toolkit](/architecture/kernel-toolkit)).

## The blocks

Read this as independent blocks that use each other through narrow seams but do
not care about each other's internals.

```
CLI + Config  (dart:io)
      │
      ▼
Engine  (zero dart:io)
 ├─ Orchestrator           RefractorEngine · PassRegistry · PassRunner
 │    ├─ Passes            nine passes — rename · encrypt · mangle · flow …
 │    │    ├─ Policy       ObfuscationScope = ProjectScope + KeepPolicy
 │    │    └─ kernel_toolkit   shared kernel operations
 │    └─ Compile / serialize boundary   Compiler · KernelIO (abstract)
 └─ IO implementations injected by the CLI:  DartCompiler · FileKernelIO
```

| Block | What it owns | More |
|---|---|---|
| **CLI + Config** | User-facing commands and translating `refractor.yaml` into typed config. The only layer allowed `dart:io`. | — |
| **Orchestrator** | Creating, ordering, and running passes; collecting results; refusing to emit output on failure. | [Passes](/architecture/passes) |
| **Pass** | One unit of obfuscation, internally a 5-stage pipeline. | [Passes](/architecture/passes) |
| **Policy** | The single "may I transform this node?" authority — membership + keep. | [Policy](/architecture/policy) |
| **Compile/serialize boundary** | Abstract `Compiler` + `KernelIO`; the engine depends on interfaces, the CLI injects the `dart:io` implementations. | below |
| **kernel_toolkit** | The shared vocabulary passes use instead of touching raw `package:kernel`. | [kernel_toolkit](/architecture/kernel-toolkit) |

## The load-bearing rule: pure engine, injected IO

Dependency direction is strict and one-way:

```
CLI (dart:io)  →  Config  →  Engine (zero dart:io)
```

The engine never imports `dart:io`. It depends on two abstract interfaces —
`Compiler` (compile source→kernel, kernel→target) and `KernelIO` (read/write
`.dill`) — and the CLI supplies the concrete implementations (`DartCompiler`,
which shells out to `dart compile`, and `FileKernelIO`). This is what makes the
whole engine unit-testable without spawning processes or touching disk, and it
is the seam a different backend would plug into.

## The compile/serialize pipeline

`RefractorEngine.run` is the orchestrator's spine. The obfuscation passes are
only the middle of a longer pipeline:

1. `compiler.compileToKernel(input)` → `app.dill`
2. `kernelIO.load(...)` → `Component` (the kernel AST)
3. build `ProjectScope`, then `PassRegistry.createAll(...)` → `List<Pass>`
4. `PassRunner.run(component)` → passes mutate the AST, results collected
5. if any pass failed → **stop**, emit no output (never ship a half-obfuscated
   binary)
6. `kernelIO.write(...)` → `app.obfuscated.dill`
7. `compiler.compileToTarget(...)` → `exe` / `aot` / `jit` (or the kernel is the
   output directly)

## Where to go next

- [Passes](/architecture/passes) — the pass framework and the concrete passes.
- [Policy](/architecture/policy) — membership vs keep, and the one scope oracle.
- [kernel_toolkit](/architecture/kernel-toolkit) — the shared kernel-operations layer and the design philosophy behind it.
