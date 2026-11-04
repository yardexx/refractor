import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:jaspr_content/jaspr_content.dart';

import '../rulebook/passes.dart';
import 'pass_compare_card.dart';

/// A side-by-side before/after comparison in the landing page's code card.
///
/// In markdown, wrap two fenced code blocks (before, then after):
///
/// ````md
/// <PassCompare pass="rename">
///
/// ```dart
/// class PaymentProcessor {}
/// ```
///
/// ```dart
/// class a {}
/// ```
///
/// </PassCompare>
/// ````
///
/// Both snippets are syntax-highlighted and diffed token by token: what the
/// pass changed glows in the pass's color in the "after" pane, and what it
/// replaced is marked in the "before" pane.
class PassCompare extends CustomComponent {
  PassCompare() : super.base();

  @override
  Component? create(Node node, NodesBuilder builder) {
    if (node case ElementNode(tag: 'PassCompare', :final attributes, :final children?)) {
      final blocks = children.expand(_codeBlocks).toList();
      if (blocks.length != 2) {
        throw ArgumentError('<PassCompare> needs two code blocks (before, after); found ${blocks.length}.');
      }
      return Component.fragment([
        Document.head(
          children: [link(id: 'code-card-css', rel: 'stylesheet', href: '/styles/code-card.css')],
        ),
        PassCompareCard(pass: passBySlug(attributes['pass'] ?? '').slug, before: blocks[0], after: blocks[1]),
      ]);
    }
    return null;
  }

  static Iterable<String> _codeBlocks(Node node) sync* {
    if (node case ElementNode(tag: 'pre', :final children?)) {
      yield children.map((c) => c.innerText).join().trimRight();
    } else if (node case ElementNode(:final children?)) {
      for (final child in children) {
        yield* _codeBlocks(child);
      }
    }
  }
}
