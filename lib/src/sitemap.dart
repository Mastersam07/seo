import 'metadata.dart';
import 'serialize.dart';

/// A render-ready sitemap entry: an absolute, canonical [loc] plus the optional
/// hints for it, with image URLs already resolved to absolute.
typedef SitemapEntry = ({
  String loc,
  DateTime? lastmod,
  SeoChangeFreq? changeFreq,
  double? priority,
  List<String> images,
});

/// Formats a sitemap.xml from the [entries] the builder collected for indexable
/// pages. Emits `<lastmod>`/`<changefreq>`/`<priority>` where set and image
/// entries under the image-sitemap namespace.
String renderSitemap(Iterable<SitemapEntry> entries) {
  final out = StringBuffer();
  out.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  out.writeln(
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" '
    'xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">',
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
