---
title: Architecture Overview
description: How Refractor is put together, from the compile pipeline to the parts of the engine.
layout: docs
---

Refractor never edits your source code. It compiles your entrypoint to a kernel
file (`.dill`, Dart's intermediate representation), rewrites the program inside
that file, and then compiles the rewritten kernel into the binary you ship. The
diagram below walks through each step.

<PipelineDiagram />

Working on kernel instead of source is the decision the rest of the design
follows from. By the time Refractor reads the `.dill`, the Dart front end has
already worked out every type, which method each call goes to, and which members
override which. Safe renaming depends on all of that, so the passes work with
`package:kernel` directly rather than through an abstraction. The
[kernel_toolkit](/architecture/kernel-toolkit) page explains why.

## The parts

Refractor is split into a few parts that talk to each other through small
interfaces. The CLI reads your config and starts a build, the engine runs the
passes, and each pass asks the policy which parts of the program it may change.
Click through them below.

<BlocksDiagram />

| Part | What it does | More |
|---|---|---|
| CLI and config | The commands you run, and turning `refractor.yaml` into typed settings. The only part that touches `dart:io`. | |
| Orchestrator | Builds the passes, runs them in order, collects their results, and refuses to write output if any failed. | [Passes](/architecture/passes) |
| Passes | One kind of obfuscation each, all built the same way in five stages. | [Passes](/architecture/passes) |
| Policy | Answers one question for every pass: may I change this declaration? | [Policy](/architecture/policy) |
| Compile/serialize boundary | Two interfaces, `Compiler` and `KernelIO`. The engine depends on them; the CLI provides the real implementations. | |
| kernel_toolkit | Shared helpers the passes use instead of handling raw `package:kernel` everywhere. | [kernel_toolkit](/architecture/kernel-toolkit) |

## Why the engine never touches the disk

Dependencies point one way. The CLI depends on the config, the config feeds the
engine, and nothing in the engine imports `dart:io`.

<DependencyRule />

The engine works against two interfaces instead: `Compiler`, which turns source
into kernel and kernel into a target, and `KernelIO`, which reads and writes
`.dill` files. The CLI passes in the real versions, `DartCompiler` (which runs
`dart compile`) and `FileKernelIO`. That split is why the whole engine can be
unit-tested without starting processes or writing files, and it is also where a
different backend would plug in.

## The pipeline step by step

`RefractorEngine.run` drives the whole build, and the passes are only its middle
part:

1. `compiler.compileToKernel(input)` produces `app.dill`.
2. `kernelIO.load(...)` reads it into a `Component`, the kernel AST.
3. The engine builds a `ProjectScope` and asks `PassRegistry.createAll(...)` for
   the enabled passes.
4. `PassRunner.run(component)` runs them. Each one rewrites the AST in place, and
   every result is kept.
5. If any pass failed, the build stops here and writes nothing, so you never end
   up with a half-obfuscated binary.
6. `kernelIO.write(...)` saves the rewritten program as `app.obfuscated.dill`.
7. `compiler.compileToTarget(...)` turns that into an executable or an AOT or JIT
   snapshot. For the kernel target, the `.dill` itself is the output.

## Where to go next

[Passes](/architecture/passes) covers how a pass is built and run.
[Policy](/architecture/policy) explains how Refractor decides what it may touch,
and [kernel_toolkit](/architecture/kernel-toolkit) describes the shared helpers
underneath.
