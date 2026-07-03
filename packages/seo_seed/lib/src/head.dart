import 'dart:convert';

import 'json_ld.dart';
import 'metadata.dart';
import 'paths.dart';
import 'serialize.dart';

/// Renders [SeoMetadata] into the string of `<head>` tags for one page.
///
/// Open Graph title/description fall back to the page title/description when
/// not set explicitly, which is almost always what you want.
///
/// When [siteBase] is given (origin plus any base-href prefix), relative
/// canonical, `og:url`, and image URLs are resolved to absolute — the form
/// search engines and social scrapers prefer. Without it they stay relative.
///
/// [extraJsonLd] blocks are emitted after the metadata's own — the builder uses
/// this to append an auto-generated breadcrumb.
///
/// [alternates] (locale -> absolute URL) and [xDefault] emit reciprocal
/// `hreflang` links for a localized page. [selfCanonical] is used as the
/// canonical when the metadata declares none — the builder passes the page's
/// own URL so each localized variant self-canonicalizes.
String renderHead(
  SeoMetadata m, {
  String? siteBase,
  Iterable<SeoJsonLd> extraJsonLd = const [],
  Map<String, String> alternates = const {},
  String? xDefault,
  String? selfCanonical,
}) {
  final out = StringBuffer();

  String? absolute(String? url) =>
      url == null ? null : resolveUrl(url, siteBase);

  out.writeln('<title>${escapeHtml(m.title)}</title>');
  out.writeln(
    '<meta name="description" content="${escapeAttr(m.description)}">',
  );

  if (m.criticalCss case final css?) {
    out.writeln('<style id="seo-seed-style">$css</style>');
  }

  final canonical = switch (m.canonical) {
    final c? => absolute(canonicalizeUrl(c)),
    null => selfCanonical,
  };
  if (canonical case final c?) {
    out.writeln('<link rel="canonical" href="${escapeAttr(c)}">');
  }

  for (final MapEntry(key: locale, value: url) in alternates.entries) {
    out.writeln(
      '<link rel="alternate" hreflang="${escapeAttr(locale)}" '
      'href="${escapeAttr(url)}">',
    );
  }
  if (xDefault case final url?) {
    out.writeln(
      '<link rel="alternate" hreflang="x-default" href="${escapeAttr(url)}">',
    );
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
    tag('og:image', absolute(og.image));
    tag('og:url', switch (og.url) {
      final u? => absolute(canonicalizeUrl(u)),
      null => canonical,
    });
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
    tag('twitter:image', absolute(tw.image ?? m.openGraph?.image));
  }

  for (final MapEntry(:key, :value) in m.extraMeta.entries) {
    out.writeln(
      '<meta name="${escapeAttr(key)}" content="${escapeAttr(value)}">',
    );
  }

  for (final jsonLd in [...m.jsonLd, ...extraJsonLd]) {
    // The JSON lives in a raw-text <script> element, so package:html never
    // sanitizes it — this escaping is the only guard. Encoding every `<` and
    // `>` as its JSON `\uXXXX` form neutralizes `</script>`, `<!--`, and
    // `<script>` (all of which can end or mis-nest the script context) while
    // still parsing back to the original characters. `<` only appears inside
    // JSON string data, so the escape is always valid.
    final encoded = const JsonEncoder()
        .convert(jsonLd.data)
        .replaceAll('<', r'\u003c')
        .replaceAll('>', r'\u003e');
    out.writeln('<script type="application/ld+json">$encoded</script>');
  }

  return out.toString();
}
