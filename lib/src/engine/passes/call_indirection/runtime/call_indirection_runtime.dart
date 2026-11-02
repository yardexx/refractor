/// Plain-Dart source of the call-indirection runtime helper.
///
/// Compiled to kernel and injected into the program (see
/// `SourceHelperInjector`), then referenced by the transformer in place of
/// each direct static call.
///
/// The `@pragma('vm:never-inline')` is load-bearing: it stops the AOT compiler
/// from inlining the forwarder and recovering the direct call edge, so the
/// invocation stays an indirect `Function.apply` dispatch in the binary.
library;

/// The top-level function name the injected helper exposes. The transformer
/// resolves the reparented procedure through `InjectedHelpers` under this
/// name, which stays valid after `rename` renames the procedure.
const String callIndirectionHelperName = 'refractorCall';

/// The Dart source compiled and injected as the call-indirection helper.
const String callIndirectionRuntimeSource = '''
@pragma('vm:never-inline')
dynamic refractorCall(Function target, List<Object?> positionalArguments) =>
    Function.apply(target, positionalArguments);

// Required so `dart compile kernel` accepts the helper as an entrypoint. It
// lives in the helper library, which is dropped after `refractorCall` is
// reparented, so it never reaches the obfuscated program.
void main() {}
''';
