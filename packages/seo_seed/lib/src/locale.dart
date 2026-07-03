import 'paths.dart';

/// Strategy for turning a `(locale, route path)` pair into the path and
/// absolute URL used for output files, canonical/sitemap URLs, and `hreflang`
/// alternates.
///
/// The default [PathPrefixLocales] puts the locale in a leading path segment
/// (`/fr/pricing`). Implement this interface to support subdomain- or
/// domain-based locales (`fr.example.com`, `example.fr`).
abstract interface class SeoLocaleStrategy {
  /// The site-root-relative path for [routePath] in [locale], e.g. `/fr/pricing`.
  String pathFor(String locale, String routePath);

  /// The absolute URL for [routePath] in [locale]. [siteBase] is the configured
  /// origin plus any base-href prefix (no trailing slash); path-based
  /// strategies join onto it, host-based ones may use a per-locale origin.
  String urlFor(String locale, String routePath, String siteBase);
}

/// Locale-as-path-prefix: `/pricing` in `fr` becomes `/fr/pricing`. The default
/// strategy, and the one that fits single-origin static hosting.
class PathPrefixLocales implements SeoLocaleStrategy {
  const PathPrefixLocales();

  @override
  String pathFor(String locale, String routePath) =>
      canonicalizeUrl('/$locale$routePath');

  @override
  String urlFor(String locale, String routePath, String siteBase) =>
      canonicalizeUrl('$siteBase/$locale$routePath');
}

/// Locale-as-subdomain: `/pricing` in `fr` is served at
/// `https://fr.example.com/pricing`. Files are still written under a `/<locale>`
/// directory on disk, so point each subdomain at its subdirectory when hosting.
class SubdomainLocales implements SeoLocaleStrategy {
  const SubdomainLocales({required this.domain, this.scheme = 'https'});

  /// The apex domain the locale subdomain is prefixed onto, e.g. `example.com`.
  final String domain;
  final String scheme;

  @override
  String pathFor(String locale, String routePath) =>
      canonicalizeUrl('/$locale$routePath');

  @override
  String urlFor(String locale, String routePath, String siteBase) =>
      canonicalizeUrl('$scheme://$locale.$domain$routePath');
}

/// Locale-as-domain: each locale maps to its own [origins] entry, e.g.
/// `{'en': 'https://example.com', 'fr': 'https://example.fr'}`. Files are
/// written under a `/<locale>` directory on disk; point each domain at its
/// subdirectory when hosting.
class DomainLocales implements SeoLocaleStrategy {
  const DomainLocales(this.origins);

  /// Locale -> site origin (scheme + host, no trailing slash needed).
  final Map<String, String> origins;

  @override
  String pathFor(String locale, String routePath) =>
      canonicalizeUrl('/$locale$routePath');

  @override
  String urlFor(String locale, String routePath, String siteBase) {
    if (origins[locale] case final origin?) {
      return canonicalizeUrl(
        '${origin.replaceAll(RegExp(r'/+$'), '')}$routePath',
      );
    }
    throw StateError(
      "DomainLocales has no origin configured for locale '$locale'. "
      "Configured locales: ${origins.keys.join(', ')}.",
    );
  }
}
