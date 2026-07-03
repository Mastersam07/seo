import 'builder.dart' show renderSeoPage;
import 'locale.dart';
import 'params.dart';
import 'paths.dart';
import 'route.dart';

/// Renders a page for one request URL, on demand, using the *same* route
/// callbacks and assembly as the build-time [SeoBuilder] — so a server can serve
/// always-fresh SEO HTML (prices, stock, personalized copy) for content that
/// can't be baked at build time. This is the per-request analogue of static
/// generation; wire [render] into any server or edge handler.
///
/// [shell] is the `flutter build web` `index.html` (read once at startup);
/// [siteBase] is the origin plus any base-href prefix, used to absolutize URLs.
class SeoRenderer {
  SeoRenderer(
    this.routes, {
    required this.shell,
    this.siteBase,
    this.baseHref = '/',
    this.defaultLocale,
    this.localeStrategy = const PathPrefixLocales(),
  });

  final List<SeoRoute> routes;
  final String shell;
  final String? siteBase;
  final String baseHref;
  final String? defaultLocale;
  final SeoLocaleStrategy localeStrategy;

  /// Renders the page for [requestPath] (e.g. `/post/rent`, `/fr/pricing`), or
  /// null when no route matches or the route's callbacks reject it (e.g. an
  /// unknown id throws) — in which case the caller should fall back to serving
  /// the app shell, exactly like the SPA rewrite for static hosting.
  Future<String?> render(String requestPath) async {
    final path = canonicalizeUrl(
      requestPath.isEmpty ? '/' : requestPath.split('?').first,
    );
    for (final route in routes) {
      if (_match(route, path) case (:final params, :final locale)?) {
        try {
          final rendered = await renderSeoPage(
            route: route,
            params: params,
            locale: locale,
            shell: shell,
            baseHref: baseHref,
            siteBase: siteBase,
            localeStrategy: localeStrategy,
            defaultLocale: defaultLocale,
          );
          return rendered.html;
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  ({SeoParams params, String? locale})? _match(SeoRoute route, String path) {
    if (route.locales.isEmpty) {
      if (_matchPattern(route.path, path) case final params?) {
        return (params: params, locale: null);
      }
      return null;
    }
    for (final locale in route.locales) {
      final prefix = '/$locale';
      if (path == prefix || path.startsWith('$prefix/')) {
        final rest = path.substring(prefix.length);
        final params = _matchPattern(route.path, rest.isEmpty ? '/' : rest);
        if (params != null) {
          return (params: params.withLocale(locale), locale: locale);
        }
      }
    }
    return null;
  }

  /// Matches a route [pattern] like `/post/[slug]` against a concrete [path],
  /// returning the captured params, or null when they don't line up.
  static SeoParams? _matchPattern(String pattern, String path) {
    final patternSegments = _segments(pattern);
    final pathSegments = _segments(path);
    if (patternSegments.length != pathSegments.length) return null;
    final values = <String, String>{};
    for (var i = 0; i < patternSegments.length; i++) {
      final segment = patternSegments[i];
      if (segment.startsWith('[') && segment.endsWith(']')) {
        values[segment.substring(1, segment.length - 1)] = pathSegments[i];
      } else if (segment != pathSegments[i]) {
        return null;
      }
    }
    return SeoParams(values);
  }

  static List<String> _segments(String path) =>
      path.split('/').where((s) => s.isNotEmpty).toList();
}
