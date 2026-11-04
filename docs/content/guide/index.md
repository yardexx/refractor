---
layout: docs
---

# Refractor

Refractor is an obfuscation tool for Dart code. It applies obfuscation directly
at the kernel bytecode level.

<Warning>

Refractor is in early development. Real impact on the generated binary may vary.

</Warning>

If you'd rather start using it straight away, the [Quickstart](/guide/quickstart)
gets you from install to an obfuscated binary in a few minutes.

## How it works

Refractor sits between the Dart compiler and your final binary. It compiles your
entrypoint to a kernel (`.dill`) file, rewrites the program in memory, and then
compiles the result into a native executable, an AOT or JIT snapshot, or kernel
again. Your source code is never changed.

Working on kernel is also what keeps the changes safe. By the time Refractor sees
your program, the Dart front end has resolved every type, call and override, so a
renamed method is renamed at every call site, and a method that overrides one
from Flutter keeps its name. [Architecture](/architecture) covers the details.

## What it does

The work is done by passes, each a separate kind of obfuscation that you switch on
in `refractor.yaml`. Some hide names and constants: rename gives identifiers
meaningless names, and the encryption passes hide string and integer literals
behind decoders. One rewrites integer arithmetic into equivalent but
harder-to-read forms. The rest change the shape of the code with fake conditions,
flattened functions, dead and duplicated branches, and indirect calls. The
[Rulebook](/rulebook) has a page for each.

When rename runs, the build also writes a `symbol_map.json`. Keep it, and
[`refractor symbolicate`](/recipes/symbolication) can turn an obfuscated stack
trace back into your own names later. Every build ends with a report of what each
pass changed, which also shows up in the job summary when you build in GitHub
Actions.

## SDK compatibility

Refractor works with one Dart SDK version at a time, because it bundles its own
copy of the kernel library and that copy only understands one SDK's format. This
release needs Dart **3.11.3**.

## Next steps

<Cards>
<Card title="Quickstart" href="/guide/quickstart">

Install Refractor and obfuscate your first build.

</Card>
<Card title="Commands" href="/guide/commands">

What `build`, `symbolicate`, `inspect` and `init` do, and their flags.

</Card>
<Card title="Configuration" href="/guide/configuration">

Every setting in `refractor.yaml`, with its default.

</Card>
<Card title="Architecture" href="/architecture">

How Refractor is put together, from compiler to binary.

</Card>
</Cards>

## Project & license

Refractor is open source at
[github.com/yardexx/refractor](https://github.com/yardexx/refractor). Issues and
contributions are welcome, and the repository's `LICENSE` file has the licensing
terms.
