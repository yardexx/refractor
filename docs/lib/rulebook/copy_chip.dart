import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
// The same icons as jaspr_content's code-block copy button.
import 'package:jaspr_content/components/_internal/icon.dart';
import 'package:universal_web/web.dart' as web;

/// A monospace chip that copies [text] to the clipboard when clicked.
@client
class CopyChip extends StatefulComponent {
  const CopyChip({required this.text, super.key});

  final String text;

  @override
  State<CopyChip> createState() => _CopyChipState();
}

class _CopyChipState extends State<CopyChip> {
  bool _copied = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  void _copy() {
    web.window.navigator.clipboard.writeText(component.text);
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(const Duration(seconds: 2), () => setState(() => _copied = false));
  }

  @override
  Component build(BuildContext context) {
    return button(
      classes: 'pf-chip pf-copy${_copied ? ' copied' : ''}',
      attributes: {'title': _copied ? 'Copied' : 'Copy config key', 'aria-label': 'Copy ${component.text}'},
      onClick: _copy,
      [
        code([Component.text(component.text)]),
        span(classes: 'pf-copy-icon', [_copied ? CheckIcon(size: 14) : CopyIcon(size: 14)]),
      ],
    );
  }
}
