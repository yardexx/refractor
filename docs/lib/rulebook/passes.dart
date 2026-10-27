/// The Rulebook's passes, in Rulebook order. One source for the facts strip,
/// the previous/next pager and the overview grid.
library;

enum PassGroup {
  naming('Naming & data'),
  expressions('Expressions'),
  controlFlow('Control flow')
  ;

  const PassGroup(this.label);

  final String label;
}

class PassInfo {
  const PassInfo({
    required this.slug,
    required this.page,
    required this.title,
    required this.group,
    required this.configKey,
    required this.summary,
    required this.before,
    required this.after,
    this.inStarterConfig = false,
    this.keepsEntryPoint = false,
  });

  /// Color and CSS hook (`pc-<slug>`, `--ray-<slug>`).
  final String slug;

  /// Path of the Rulebook page.
  final String page;

  final String title;
  final PassGroup group;

  /// The key under `refractor.passes` in `refractor.yaml`.
  final String configKey;

  final String summary;

  /// A one-line taste of the pass for the overview grid.
  final String before;
  final String after;

  /// Whether `refractor init` turns the pass on in the starter config.
  final bool inStarterConfig;

  /// Whether the pass keeps `main`'s name (`KeepSource.entryPoint`). Every pass
  /// honors excludes and `@Refractor.keep()`.
  final bool keepsEntryPoint;
}

const rulebookPasses = [
  PassInfo(
    slug: 'rename',
    page: '/rulebook/rename',
    title: 'Rename',
    group: PassGroup.naming,
    configKey: 'rename',
    summary: 'Rewrites identifiers to short, meaningless names.',
    before: 'chargeCard(token)',
    after: 'c(d)',
    inStarterConfig: true,
    keepsEntryPoint: true,
  ),
  PassInfo(
    slug: 'strings',
    page: '/rulebook/string-encryption',
    title: 'String encryption',
    group: PassGroup.naming,
    configKey: 'string_encrypt',
    summary: 'Hides string literals behind a runtime decoder.',
    before: "'Acme Pay'",
    after: 'refractorDecode([…])',
    inStarterConfig: true,
  ),
  PassInfo(
    slug: 'ints',
    page: '/rulebook/int-encryption',
    title: 'Integer encryption',
    group: PassGroup.naming,
    configKey: 'int_encrypt',
    summary: 'Hides integer literals behind a runtime decoder.',
    before: '30000',
    after: 'refractorDecodeInt(…)',
  ),
  PassInfo(
    slug: 'arith',
    page: '/rulebook/arithmetic-mangling',
    title: 'Arithmetic mangling',
    group: PassGroup.expressions,
    configKey: 'arithmetic_mangle',
    summary: 'Rewrites + and * into equivalent, uglier expressions.',
    before: 'a + b',
    after: '(a ^ b) + ((a & b) << 1)',
  ),
  PassInfo(
    slug: 'opaque',
    page: '/rulebook/opaque-predicates',
    title: 'Opaque predicates',
    group: PassGroup.controlFlow,
    configKey: 'opaque_predicate',
    summary: 'Entangles branch conditions with always-true predicates.',
    before: 'if (paid)',
    after: 'if (paid && n² >= 0)',
  ),
  PassInfo(
    slug: 'flatten',
    page: '/rulebook/control-flow-flatten',
    title: 'Control-flow flattening',
    group: PassGroup.controlFlow,
    configKey: 'control_flow_flatten',
    summary: 'Turns a straight-line body into a switch state machine.',
    before: 'a(); b(); c();',
    after: 'switch (2) { case 0: … }',
  ),
  PassInfo(
    slug: 'dead',
    page: '/rulebook/dead-code',
    title: 'Dead code',
    group: PassGroup.controlFlow,
    configKey: 'dead_code',
    summary: 'Inserts never-executed, opaquely guarded junk.',
    before: 'return p * 2;',
    after: 'if (p² < 0) { … } return p * 2;',
  ),
  PassInfo(
    slug: 'bogus',
    page: '/rulebook/bogus-control-flow',
    title: 'Bogus control flow',
    group: PassGroup.controlFlow,
    configKey: 'bogus_control_flow',
    summary: 'Wraps a body in an always-true branch over a real-looking clone.',
    before: '{ body }',
    after: 'if (n² >= 0) { body } else { clone }',
  ),
  PassInfo(
    slug: 'call',
    page: '/rulebook/call-indirection',
    title: 'Call indirection',
    group: PassGroup.controlFlow,
    configKey: 'call_indirection',
    summary: 'Routes static calls through a never-inline forwarder.',
    before: 'sum(items)',
    after: 'refractorCall(sum, [items])',
  ),
];

PassInfo passBySlug(String slug) =>
    rulebookPasses.firstWhere((p) => p.slug == slug, orElse: () => throw ArgumentError('Unknown pass "$slug".'));
