import 'json_ld.dart';

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
    this.jsonLd,
    this.robots,
    this.extraMeta = const {},
  });

  final String title;
  final String description;

  /// Absolute path or URL, e.g. `/post/splitting-rent`.
  final String? canonical;

  final OpenGraph? openGraph;
  final TwitterCard? twitter;
  final SeoJsonLd? jsonLd;

  /// e.g. `noindex, follow`. Omitted when null.
  final String? robots;

  /// Any additional `<meta name=... content=...>` pairs.
  final Map<String, String> extraMeta;

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
