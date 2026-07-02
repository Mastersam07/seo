import 'json_ld.dart';

/// How often a page is expected to change, for the sitemap `<changefreq>` hint.
enum SeoChangeFreq { always, hourly, daily, weekly, monthly, yearly, never }

/// Per-page sitemap hints. All fields are optional; the sitemap emits only the
/// ones you set.
class SeoSitemap {
  const SeoSitemap({
    this.lastmod,
    this.changeFreq,
    this.priority,
    this.images = const [],
  });

  /// When the page last meaningfully changed. Emitted as a `<lastmod>` date.
  final DateTime? lastmod;

  /// Expected change cadence, a hint crawlers may use for scheduling.
  final SeoChangeFreq? changeFreq;

  /// Relative importance within this site, `0.0`–`1.0` (clamped). Default `0.5`.
  final double? priority;

  /// Image URLs on the page, listed as image-sitemap entries. Relative paths
  /// are resolved against the site base like other URLs.
  final List<String> images;
}

/// Open Graph tags, used by social scrapers to build link previews.
class OpenGraph {
  const OpenGraph({
    this.title,
    this.description,
    this.image,
    this.type = 'website',
    this.url,
  });

  /// Falls back to the page [SeoMetadata.title] when null.
  final String? title;

  /// Falls back to the page [SeoMetadata.description] when null.
  final String? description;

  final String? image;
  final String type;
  final String? url;
}

/// Twitter card tags. [card] is typically `summary` or `summary_large_image`.
class TwitterCard {
  const TwitterCard({
    this.card = 'summary_large_image',
    this.site,
    this.title,
    this.description,
    this.image,
  });

  final String card;
  final String? site;
  final String? title;
  final String? description;
  final String? image;
}

/// Everything that belongs in the page `<head>` for one route.
///
/// This is the direct analogue of Expo Router's `Head` component: a
/// declaration of the page's title, description, canonical URL, and social
/// and structured-data tags.
class SeoMetadata {
  const SeoMetadata({
    required this.title,
    required this.description,
    this.canonical,
    this.openGraph,
    this.twitter,
    this.jsonLd = const [],
    this.breadcrumbs = false,
    this.robots,
    this.extraMeta = const {},
    this.sitemap,
    this.criticalCss,
  });

  final String title;
  final String description;

  /// Absolute path or URL, e.g. `/post/splitting-rent`.
  final String? canonical;

  final OpenGraph? openGraph;
  final TwitterCard? twitter;

  /// Structured-data blocks for this page; each is emitted as its own
  /// `<script type="application/ld+json">`. A page may declare several
  /// (e.g. an `Article` plus a `BreadcrumbList`).
  final List<SeoJsonLd> jsonLd;

  /// When true, the builder appends a `BreadcrumbList` derived from this page's
  /// route path (see [SeoJsonLd.breadcrumbTrail]), with absolute URLs when a
  /// site base is configured.
  final bool breadcrumbs;

  /// e.g. `noindex, follow`. Omitted when null.
  final String? robots;

  /// Any additional `<meta name=... content=...>` pairs.
  final Map<String, String> extraMeta;

  /// Optional sitemap hints (`lastmod`, `changefreq`, `priority`, images) for
  /// this page's entry. Ignored for non-indexable pages, which are omitted.
  final SeoSitemap? sitemap;

  /// Optional CSS inlined in `<head>` (as `<style id="seo-seed-style">`) to
  /// style the crawler seed block so it paints as a styled above-the-fold hero
  /// before the Flutter engine boots — the largest Core Web Vitals lever for a
  /// canvas app. Target `#seo-seed` and its children. Both the seed and this
  /// style are removed by `SeoRuntime.takeover()`, so the rules never leak into
  /// the running app. Emitted verbatim, so pass only CSS you control.
  final String? criticalCss;

  /// Whether this page should be advertised in the sitemap: false when [robots]
  /// opts out of indexing (`noindex`, or the `none` directive). The page is
  /// still generated and crawlable so the `noindex` meta is actually seen — it
  /// is only kept out of the sitemap, keeping the two signals consistent.
  bool get indexable {
    if (robots?.toLowerCase() case final r?) {
      return !(r.contains('noindex') || RegExp(r'\bnone\b').hasMatch(r));
    }
    return true;
  }
}
