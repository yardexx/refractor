import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:universal_web/web.dart' as web;

/// The copy button in a code panel's header.
@client
class CopyCodeButton extends StatefulComponent {
  const CopyCodeButton({required this.text, super.key});

  final String text;

  @override
  State<CopyCodeButton> createState() => _CopyCodeButtonState();
}

class _CopyCodeButtonState extends State<CopyCodeButton> {
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
      classes: 'cb-copy${_copied ? ' copied' : ''}',
      attributes: {'aria-label': 'Copy code'},
      onClick: _copy,
      [Component.text(_copied ? 'Copied' : 'Copy')],
    );
  }
}
