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
