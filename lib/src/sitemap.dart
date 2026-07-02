import 'serialize.dart';

/// Formats a sitemap.xml from the absolute, already-canonical [locs] the
/// builder collected for indexable pages.
String renderSitemap(Iterable<String> locs) {
  final out = StringBuffer();
  out.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  out.writeln('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">');
  for (final loc in locs) {
    out.writeln('  <url><loc>${escapeHtml(loc)}</loc></url>');
  }
  out.writeln('</urlset>');
  return out.toString();
}
