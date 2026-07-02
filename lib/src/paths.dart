/// The package's canonical URL form: no trailing slash, except a bare root `/`.
///
/// Enforced uniformly on route paths, sitemap `<loc>` entries, and
/// `<link rel="canonical">` so `/post/abc` and `/post/abc/` never split ranking
/// signal or create duplicate-content ambiguity. Only the trailing slash is
/// touched, so an absolute URL keeps its `https://` scheme and a path that is
/// nothing but slashes collapses to a single `/`.
String canonicalizeUrl(String url) {
  if (url.isEmpty) return '/';
  final trimmed = url.replaceAll(RegExp(r'/+$'), '');
  return trimmed.isEmpty ? '/' : trimmed;
}

/// Resolves [url] to an absolute URL against [siteBase] (origin plus any
/// base-href prefix, no trailing slash), which is what search engines and
/// social scrapers prefer for canonicals, `og:url`, and images.
///
/// A [url] that is already absolute (has a scheme, or is protocol-relative) is
/// returned unchanged. A relative [url] is joined onto [siteBase]. When
/// [siteBase] is null (no site origin configured) [url] is returned as-is, so
/// output stays relative rather than wrong.
String resolveUrl(String url, String? siteBase) {
  if (siteBase == null || _isAbsolute(url)) return url;
  return '$siteBase${url.startsWith('/') ? url : '/$url'}';
}

bool _isAbsolute(String url) =>
    url.startsWith('//') || RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(url);
