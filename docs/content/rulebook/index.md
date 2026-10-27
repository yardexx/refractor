---
title: Rulebook
description: What each obfuscation pass does to your code, and how to tune it.
layout: docs
---

The Rulebook describes what each pass does to your code and how to configure it.
If you want to know how the passes are built and run instead, that's in
[Architecture](/architecture).

A pass is one kind of obfuscation. Refractor runs the passes you enable, one
after another, over your compiled program. They fall into three groups: naming
and data passes hide the names and constants a reader relies on, expression
passes make calculations harder to follow, and control-flow passes blur the
shape of the program.

<PassGrid />

## How to read a rule page

Every pass page has the same sections in the same order, so you always know where
to look. The list also works as a checklist when adding a new pass.

1. **Facts:** the pass's group, its config key, and whether it is stable (shipped
   in a release) or experimental.
2. **What it does:** the effect on your code, in a paragraph.
3. **Example:** before and after side by side, with the changes highlighted.
4. **What it targets:** what the pass changes, what it skips, and which keep rules
   it follows.
5. **Configuration:** a minimal setup, then every option with its default.
6. **Guarantees & limitations:** what the pass promises, next to what it doesn't
   do.
7. **Output:** the metrics it adds to the build report, and any artifact it
   writes.

<Info>

Refractor only ever obfuscates your own project: libraries named after the
package in your `pubspec.yaml`, and files under the project root. Dependencies
and the SDK are never touched. [Policy](/architecture/policy) has the exact rule.

</Info>
