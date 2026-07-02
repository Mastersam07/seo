import 'metadata.dart';
import 'serialize.dart';

/// A render-ready sitemap entry: an absolute, canonical [loc] plus the optional
/// hints for it, with image and alternate URLs already resolved to absolute.
/// [alternates] maps locale -> URL for `hreflang` alternates (empty when the
/// page is not localized).
typedef SitemapEntry = ({
  String loc,
  DateTime? lastmod,
  SeoChangeFreq? changeFreq,
  double? priority,
  List<String> images,
  Map<String, String> alternates,
});

/// Formats a sitemap.xml from the [entries] the builder collected for indexable
/// pages. Emits `<lastmod>`/`<changefreq>`/`<priority>` where set, image entries
/// under the image namespace, and `hreflang` alternates under the xhtml
/// namespace.
String renderSitemap(Iterable<SitemapEntry> entries) {
  final out = StringBuffer();
  out.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  out.writeln(
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" '
    'xmlns:image="http://www.google.com/schemas/sitemap-image/1.1" '
    'xmlns:xhtml="http://www.w3.org/1999/xhtml">',
  );
  for (final entry in entries) {
    out.writeln('  <url>');
    out.writeln('    <loc>${escapeHtml(entry.loc)}</loc>');
    if (entry.lastmod case final lastmod?) {
      out.writeln('    <lastmod>${_isoDate(lastmod)}</lastmod>');
    }
    if (entry.changeFreq case final freq?) {
      out.writeln('    <changefreq>${freq.name}</changefreq>');
    }
    if (entry.priority case final priority?) {
      out.writeln(
        '    <priority>${priority.clamp(0.0, 1.0).toStringAsFixed(1)}</priority>',
      );
    }
    for (final MapEntry(key: locale, value: url) in entry.alternates.entries) {
      out.writeln(
        '    <xhtml:link rel="alternate" hreflang="${escapeHtml(locale)}" '
        'href="${escapeHtml(url)}"/>',
      );
    }
    for (final image in entry.images) {
      out.writeln('    <image:image>');
      out.writeln('      <image:loc>${escapeHtml(image)}</image:loc>');
      out.writeln('    </image:image>');
    }
    out.writeln('  </url>');
  }
  out.writeln('</urlset>');
  return out.toString();
}

/// A `<lastmod>` value in W3C `YYYY-MM-DD` form (UTC).
String _isoDate(DateTime d) {
  final u = d.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)}';
}
