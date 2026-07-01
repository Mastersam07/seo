/// A node in the crawler-facing content tree.
///
/// This is deliberately plain data, not a Flutter widget. The build step runs
/// in a bare Dart VM with no `dart:ui`, no engine, and no widget layer, so the
/// content a route contributes for crawlers must be representable without any
/// of that. A tree of [SeoNode]s serializes to an HTML string with no runtime
/// dependencies.
sealed class SeoNode {
  const SeoNode();
}

/// An HTML element with a tag, attributes, and children.
class SeoElement extends SeoNode {
  const SeoElement(
    this.tag, {
    this.attributes = const {},
    this.children = const [],
    this.selfClosing = false,
  });

  final String tag;
  final Map<String, String> attributes;
  final List<SeoNode> children;
  final bool selfClosing;
}

/// A run of text. When [raw] is true the value is emitted verbatim (use only
/// for content you have already escaped or trust); otherwise it is HTML-escaped
/// on serialization.
class SeoText extends SeoNode {
  const SeoText(this.value, {this.raw = false});

  final String value;
  final bool raw;
}

/// Builder for [SeoNode] content trees, passed to a route's content callback.
///
/// Container methods accept [Object] content that is normalized to children:
/// a `String` becomes a text node, a single `SeoNode` becomes one child, and a
/// `List<SeoNode>` is used as-is. This keeps call sites terse:
///
/// ```dart
/// b.article([
///   b.h1('Splitting rent fairly'),
///   b.p('Sortd divides shared costs and simplifies who pays whom.'),
/// ])
/// ```
class SeoHtml {
  const SeoHtml();

  List<SeoNode> _children(Object? content) => switch (content) {
    null => const [],
    String s => [SeoText(s)],
    SeoNode n => [n],
    List<SeoNode> l => l,
    Iterable<Object?> it => [
      for (final e in it)
        if (e is SeoNode) e else SeoText(e.toString()),
    ],
    _ => [SeoText(content.toString())],
  };

  SeoNode text(String value) => SeoText(value);

  /// Emits [value] without escaping. Only for trusted, pre-escaped HTML.
  SeoNode raw(String value) => SeoText(value, raw: true);

  SeoNode h1(Object content) => SeoElement('h1', children: _children(content));
  SeoNode h2(Object content) => SeoElement('h2', children: _children(content));
  SeoNode h3(Object content) => SeoElement('h3', children: _children(content));
  SeoNode p(Object content) => SeoElement('p', children: _children(content));

  SeoNode article(Object content) =>
      SeoElement('article', children: _children(content));
  SeoNode section(Object content) =>
      SeoElement('section', children: _children(content));
  SeoNode div(Object content) =>
      SeoElement('div', children: _children(content));
  SeoNode nav(Object content) =>
      SeoElement('nav', children: _children(content));
  SeoNode header(Object content) =>
      SeoElement('header', children: _children(content));
  SeoNode footer(Object content) =>
      SeoElement('footer', children: _children(content));

  SeoNode span(Object content) =>
      SeoElement('span', children: _children(content));
  SeoNode strong(Object content) =>
      SeoElement('strong', children: _children(content));
  SeoNode em(Object content) => SeoElement('em', children: _children(content));

  SeoNode ul(List<SeoNode> items) => SeoElement('ul', children: items);
  SeoNode ol(List<SeoNode> items) => SeoElement('ol', children: items);
  SeoNode li(Object content) => SeoElement('li', children: _children(content));

  SeoNode a(String href, Object content) =>
      SeoElement('a', attributes: {'href': href}, children: _children(content));

  SeoNode img(String src, {String? alt}) => SeoElement(
    'img',
    attributes: {'src': src, 'alt': ?alt},
    selfClosing: true,
  );

  SeoNode time(String datetime, Object content) => SeoElement(
    'time',
    attributes: {'datetime': datetime},
    children: _children(content),
  );
}
