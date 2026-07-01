import 'dart:convert';

import 'metadata.dart';
import 'serialize.dart';

/// Renders [SeoMetadata] into the string of `<head>` tags for one page.
///
/// Open Graph title/description fall back to the page title/description when
/// not set explicitly, which is almost always what you want.
String renderHead(SeoMetadata m) {
  final out = StringBuffer();

  out.writeln('<title>${escapeHtml(m.title)}</title>');
  out.writeln(
    '<meta name="description" content="${escapeAttr(m.description)}">',
  );

  if (m.canonical case final canonical?) {
    out.writeln('<link rel="canonical" href="${escapeAttr(canonical)}">');
  }

  if (m.robots case final robots?) {
    out.writeln('<meta name="robots" content="${escapeAttr(robots)}">');
  }

  if (m.openGraph case final og?) {
    void tag(String property, String? content) {
      if (content == null) return;
      out.writeln(
        '<meta property="$property" content="${escapeAttr(content)}">',
      );
    }

    tag('og:title', og.title ?? m.title);
    tag('og:description', og.description ?? m.description);
    tag('og:type', og.type);
    tag('og:image', og.image);
    tag('og:url', og.url ?? m.canonical);
  }

  if (m.twitter case final tw?) {
    void tag(String name, String? content) {
      if (content == null) return;
      out.writeln('<meta name="$name" content="${escapeAttr(content)}">');
    }

    tag('twitter:card', tw.card);
    tag('twitter:site', tw.site);
    tag('twitter:title', tw.title ?? m.title);
    tag('twitter:description', tw.description ?? m.description);
    tag('twitter:image', tw.image ?? m.openGraph?.image);
  }

  for (final MapEntry(:key, :value) in m.extraMeta.entries) {
    out.writeln('<meta name="$key" content="${escapeAttr(value)}">');
  }

  if (m.jsonLd case final jsonLd?) {
    // JSON is embedded in a script element. The one sequence that can break
    // out of a script context is `</`, so we escape the slash in any closing
    // tag that appears inside string data.
    final encoded = const JsonEncoder()
        .convert(jsonLd.data)
        .replaceAll('</', '<\\/');
    out.writeln('<script type="application/ld+json">$encoded</script>');
  }

  return out.toString();
}
