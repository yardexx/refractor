/// The Rulebook's passes, in Rulebook order. One source for the facts strip,
/// the previous/next pager and the overview grid.
library;

enum PassGroup {
  naming('Naming & data', 'naming'),
  expressions('Expressions', 'expressions'),
  controlFlow('Control flow', 'control')
  ;

  const PassGroup(this.label, this.slug);

  final String label;

  /// Color hook (`pc-<slug>` in code-card.css). On the docs pages a pass takes
  /// its category's color; per-pass colors are only for the landing page.
  final String slug;
}

class PassInfo {
  const PassInfo({
    required this.slug,
    required this.page,
    required this.title,
    required this.group,
    required this.configKey,
    required this.summary,
    this.stable = false,
  });

  /// The id the components' `pass="…"` attribute takes.
  final String slug;

  /// Path of the Rulebook page.
  final String page;

  final String title;
  final PassGroup group;

  /// The key under `refractor.passes` in `refractor.yaml`.
  final String configKey;

  final String summary;

  /// Whether the pass shipped in a release (0.2.2). The rest are new on dev
  /// and marked experimental.
  final bool stable;
}

const rulebookPasses = [
  PassInfo(
    slug: 'rename',
    page: '/rulebook/rename',
    title: 'Rename',
    group: PassGroup.naming,
    configKey: 'rename',
    summary: 'Rewrites identifiers to short, meaningless names.',
    stable: true,
  ),
  PassInfo(
    slug: 'strings',
    page: '/rulebook/string-encryption',
    title: 'String encryption',
    group: PassGroup.naming,
    configKey: 'string_encrypt',
    summary: 'Hides string literals behind a runtime decoder.',
    stable: true,
  ),
  PassInfo(
    slug: 'ints',
    page: '/rulebook/int-encryption',
    title: 'Integer encryption',
    group: PassGroup.naming,
    configKey: 'int_encrypt',
    summary: 'Hides integer literals behind a runtime decoder.',
  ),
  PassInfo(
    slug: 'arith',
    page: '/rulebook/arithmetic-mangling',
    title: 'Arithmetic mangling',
    group: PassGroup.expressions,
    configKey: 'arithmetic_mangle',
    summary: 'Rewrites + and * into equivalent, uglier expressions.',
  ),
  PassInfo(
    slug: 'opaque',
    page: '/rulebook/opaque-predicates',
    title: 'Opaque predicates',
    group: PassGroup.controlFlow,
    configKey: 'opaque_predicate',
    summary: 'Entangles branch conditions with always-true predicates.',
  ),
  PassInfo(
    slug: 'flatten',
    page: '/rulebook/control-flow-flatten',
    title: 'Control-flow flattening',
    group: PassGroup.controlFlow,
    configKey: 'control_flow_flatten',
    summary: 'Turns a straight-line body into a switch state machine.',
  ),
  PassInfo(
    slug: 'dead',
    page: '/rulebook/dead-code',
    title: 'Dead code',
    group: PassGroup.controlFlow,
    configKey: 'dead_code',
    summary: 'Inserts never-executed, opaquely guarded junk.',
  ),
  PassInfo(
    slug: 'bogus',
    page: '/rulebook/bogus-control-flow',
    title: 'Bogus control flow',
    group: PassGroup.controlFlow,
    configKey: 'bogus_control_flow',
    summary: 'Wraps a body in an always-true branch over a real-looking clone.',
  ),
  PassInfo(
    slug: 'call',
    page: '/rulebook/call-indirection',
    title: 'Call indirection',
    group: PassGroup.controlFlow,
    configKey: 'call_indirection',
    summary: 'Routes static calls through a never-inline forwarder.',
  ),
];

PassInfo passBySlug(String slug) =>
    rulebookPasses.firstWhere((p) => p.slug == slug, orElse: () => throw ArgumentError('Unknown pass "$slug".'));
