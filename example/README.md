A sample command-line application that doubles as an obfuscation edge-case
fixture.

It exercises:
- named-argument renaming
- dynamic get/set/invocation
- mixins and overrides
- SDK override exclusions
- local, instance, top-level, static-field, constructor, and factory tear-offs
- generic instantiations and redirecting factories
- `@pragma('vm:entry-point')` exclusions
- string interpolation and annotation-bearing declarations

Run it with:

```sh
dart run bin/app.dart --verbose
```
