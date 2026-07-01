import 'paths.dart';
import 'route.dart';
import 'serialize.dart';

/// Builds a sitemap.xml string listing every generated page.
///
/// [baseUrl] is the site origin without a trailing slash, e.g.
/// `https://sortd.app`.
Future<String> renderSitemap(List<SeoRoute> routes, String baseUrl) async {
  final origin = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;

  final locs = <String>[];
  for (final route in routes) {
    for (final params in await route.resolveParams()) {
      locs.add(canonicalizeUrl('$origin${route.resolvePath(params)}'));
    }
  }

  final out = StringBuffer();
  out.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  out.writeln('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">');
  for (final loc in locs) {
    out.writeln('  <url><loc>${escapeHtml(loc)}</loc></url>');
  }
  out.writeln('</urlset>');
  return out.toString();
}
