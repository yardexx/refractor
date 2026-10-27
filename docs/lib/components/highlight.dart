/// A small syntax highlighter for the docs' code: Dart, YAML, shell, JSON and
/// plain text. Tokens carry a CSS kind (`tk-<kind>` in code-card.css).
library;

class CodeToken {
  CodeToken(this.text, this.kind);

  final String text;

  /// `kw`, `ty`, `id`, `fn`, `str`, `num`, `lbl`, `cm`, `key`, `p`, or `ws` /
  /// `nl` for whitespace.
  String kind;

  /// Zero-based source line.
  int line = 0;

  /// Set by a diff (see PassCompare) when the token was added or replaced.
  bool changed = false;

  bool get significant => kind != 'ws' && kind != 'nl';
}

/// Tokenizes [source] for [language] (`dart`, `yaml`, `sh`, `json`, or anything
/// else for plain text).
List<CodeToken> highlight(String source, String language) {
  final tokens = switch (language) {
    'dart' => _dart(source),
    'yaml' || 'yml' => _yaml(source),
    'sh' || 'shell' || 'bash' => _shell(source),
    'json' => _json(source),
    _ => _plain(source),
  };
  var line = 0;
  for (final t in tokens) {
    t.line = line;
    if (t.kind == 'nl') line++;
  }
  return tokens;
}

/// Splits [source] on [pattern]; [classify] names each match's kind from its
/// capture groups (null for "plain").
List<CodeToken> _scan(String source, RegExp pattern, String Function(RegExpMatch m) classify) {
  return [
    for (final m in pattern.allMatches(source))
      CodeToken(
        m[0]!,
        switch (m[0]!) {
          '\n' => 'nl',
          final s when s.trim().isEmpty => 'ws',
          _ => classify(m),
        },
      ),
  ];
}

final _dartPattern = RegExp(
  r'''(//[^\n]*)|('(?:\\.|[^'\\\n])*'|"(?:\\.|[^"\\\n])*")|(0x[0-9a-fA-F]+|\d+(?:\.\d+)?)|([A-Za-z_$][\w$]*)|(\n)|([ \t]+)|(.)''',
);

const _dartKeywords = {
  'abstract', 'as', 'async', 'await', 'break', 'case', 'class', 'const', 'continue', 'else', //
  'enum', 'extends', 'false', 'final', 'for', 'if', 'implements', 'import', 'interface', 'late',
  'new', 'null', 'on', 'required', 'return', 'sealed', 'static', 'super', 'switch', 'this',
  'throw', 'true', 'try', 'catch', 'var', 'void', 'while', 'with', 'mixin',
};
const _dartBuiltinTypes = {'int', 'double', 'num', 'bool', 'dynamic', 'String', 'Object', 'Future'};

List<CodeToken> _dart(String source) {
  final tokens = _scan(source, _dartPattern, (m) {
    if (m[1] != null) return 'cm';
    if (m[2] != null) return 'str';
    if (m[3] != null) return 'num';
    if (m[4] != null) return 'id';
    return 'p';
  });
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    if (t.kind != 'id') continue;
    final next = tokens.skip(i + 1).where((n) => n.kind != 'ws').firstOrNull;
    t.kind = switch (t.text) {
      _ when _dartKeywords.contains(t.text) => 'kw',
      _ when RegExp(r'^L\d+$').hasMatch(t.text) => 'lbl',
      _ when _dartBuiltinTypes.contains(t.text) || t.text.startsWith(RegExp('[A-Z]')) => 'ty',
      _ when next?.text == '(' => 'fn',
      _ => 'id',
    };
  }
  return tokens;
}

final _yamlPattern = RegExp(
  r'''((?:^|(?<=\s))#[^\n]*)|('(?:[^'\n])*'|"(?:\\.|[^"\\\n])*")|(^[ \t]*-?[ \t]*[\w.\-]+(?=:))|(\b0x[0-9a-fA-F]+\b|\b\d+\b)|(\btrue\b|\bfalse\b|\bnull\b)|(\n)|([ \t]+)|([^\s'"#]+|.)''',
  multiLine: true,
);

List<CodeToken> _yaml(String source) {
  final tokens = <CodeToken>[];
  for (final m in _yamlPattern.allMatches(source)) {
    if (m[3] != null) {
      // A key, possibly after indentation and a list dash: split those off.
      final full = m[3]!, key = full.trimLeft().replaceFirst(RegExp(r'^-\s*'), '');
      final lead = full.substring(0, full.length - key.length);
      if (lead.isNotEmpty) tokens.add(CodeToken(lead, lead.trim().isEmpty ? 'ws' : 'p'));
      tokens.add(CodeToken(key, 'key'));
      continue;
    }
    tokens.add(
      CodeToken(m[0]!, switch (m) {
        _ when m[1] != null => 'cm',
        _ when m[2] != null => 'str',
        _ when m[4] != null => 'num',
        _ when m[5] != null => 'kw',
        _ when m[6] != null => 'nl',
        _ when m[7] != null => 'ws',
        _ when const {':', '-', '[', ']', '[]', '{}'}.contains(m[0]) => 'p',
        _ => 'id',
      }),
    );
  }
  return tokens;
}

final _shellPattern = RegExp(
  r'''(#[^\n]*)|('(?:[^'\n])*'|"(?:\\.|[^"\\\n])*")|(\s--?[\w-]+)|(\||&&|>)|(\n)|([ \t]+)|([^\s'"|&>]+)''',
);

List<CodeToken> _shell(String source) {
  final tokens = <CodeToken>[];
  var atCommandStart = true;
  for (final m in _shellPattern.allMatches(source)) {
    if (m[3] != null) {
      // A flag: keep its leading space as whitespace.
      tokens
        ..add(CodeToken(m[3]!.substring(0, 1), 'ws'))
        ..add(CodeToken(m[3]!.substring(1), 'kw'));
      continue;
    }
    final kind = switch (m) {
      _ when m[1] != null => 'cm',
      _ when m[2] != null => 'str',
      _ when m[4] != null => 'p',
      _ when m[5] != null => 'nl',
      _ when m[6] != null => 'ws',
      _ => atCommandStart ? 'fn' : 'id',
    };
    tokens.add(CodeToken(m[0]!, kind));
    if (kind == 'nl' || kind == 'p') {
      atCommandStart = true;
    } else if (kind != 'ws') {
      atCommandStart = false;
    }
  }
  return tokens;
}

final _jsonPattern = RegExp(r'''("(?:\\.|[^"\\\n])*")(\s*:)?|(-?\d+(?:\.\d+)?)|(true|false|null)|(\n)|([ \t]+)|(.)''');

List<CodeToken> _json(String source) {
  final tokens = <CodeToken>[];
  for (final m in _jsonPattern.allMatches(source)) {
    if (m[1] != null) {
      tokens.add(CodeToken(m[1]!, m[2] != null ? 'key' : 'str'));
      if (m[2] != null) tokens.add(CodeToken(m[2]!, 'p'));
      continue;
    }
    tokens.add(
      CodeToken(m[0]!, switch (m) {
        _ when m[3] != null => 'num',
        _ when m[4] != null => 'kw',
        _ when m[5] != null => 'nl',
        _ when m[6] != null => 'ws',
        _ => 'p',
      }),
    );
  }
  return tokens;
}

List<CodeToken> _plain(String source) => [
  for (final (i, line) in source.split('\n').indexed) ...[
    if (i > 0) CodeToken('\n', 'nl'),
    if (line.isNotEmpty) CodeToken(line, 'id'),
  ],
];
