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

/// Formats a sitemap index listing the shard [sitemapUrls], written as the
/// top-level `sitemap.xml` when a site has more URLs than fit in one file.
String renderSitemapIndex(Iterable<String> sitemapUrls) {
  final out = StringBuffer();
  out.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  out.writeln(
    '<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
  );
  for (final url in sitemapUrls) {
    out.writeln('  <sitemap><loc>${escapeHtml(url)}</loc></sitemap>');
  }
  out.writeln('</sitemapindex>');
  return out.toString();
}

/// Collects sitemap entries and writes them out, splitting into
/// `sitemap-N.xml` shards once a file would exceed [limit] URLs (the
/// sitemaps.org cap is 50,000). With one shard it writes a plain
/// `sitemap.xml`; with several it writes a `sitemap.xml` index over them.
///
/// [write] is injected so the caller owns file IO (and can skip it on a dry
/// run); buffering to [limit] keeps memory bounded for very large sites.
class SitemapShardWriter {
  SitemapShardWriter({
    required this.siteBase,
    required this.write,
    this.limit = 50000,
  });

  final String siteBase;
  final void Function(String filename, String content) write;
  final int limit;

  final List<SitemapEntry> _buffer = [];
  final List<String> _shards = [];

  void add(SitemapEntry entry) {
    _buffer.add(entry);
    if (_buffer.length >= limit) _flushShard();
  }

  void _flushShard() {
    final name = 'sitemap-${_shards.length + 1}.xml';
    write(name, renderSitemap(_buffer));
    _shards.add(name);
    _buffer.clear();
  }

  /// Writes any remaining entries and the top-level `sitemap.xml` (a single
  /// urlset when everything fit in one shard, otherwise a sitemap index).
  void finish() {
    if (_shards.isEmpty) {
      write('sitemap.xml', renderSitemap(_buffer));
      return;
    }
    if (_buffer.isNotEmpty) _flushShard();
    write(
      'sitemap.xml',
      renderSitemapIndex([for (final s in _shards) '$siteBase/$s']),
    );
  }
}

/// A `<lastmod>` value in W3C `YYYY-MM-DD` form (UTC).
String _isoDate(DateTime d) {
  final u = d.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)}';
}
