/// A block of JSON-LD structured data, emitted as a
/// `<script type="application/ld+json">` tag in the page head.
///
/// Use the factory constructors for common schema.org types, or pass an
/// arbitrary map to [SeoJsonLd.raw] for anything not covered.
class SeoJsonLd {
  const SeoJsonLd.raw(this.data);

  final Map<String, Object?> data;

  /// schema.org `Article`.
  factory SeoJsonLd.article({
    required String headline,
    String? description,
    DateTime? datePublished,
    DateTime? dateModified,
    String? authorName,
    String? imageUrl,
  }) {
    return SeoJsonLd.raw({
      '@context': 'https://schema.org',
      '@type': 'Article',
      'headline': headline,
      'description': ?description,
      'datePublished': ?datePublished?.toIso8601String(),
      'dateModified': ?dateModified?.toIso8601String(),
      if (authorName case final name?)
        'author': {'@type': 'Person', 'name': name},
      'image': ?imageUrl,
    });
  }

  /// schema.org `WebSite`, useful on a landing page.
  factory SeoJsonLd.website({
    required String name,
    required String url,
    String? description,
  }) {
    return SeoJsonLd.raw({
      '@context': 'https://schema.org',
      '@type': 'WebSite',
      'name': name,
      'url': url,
      'description': ?description,
    });
  }

  /// schema.org `BreadcrumbList`. [items] is ordered name -> url.
  factory SeoJsonLd.breadcrumb(List<({String name, String url})> items) {
    return SeoJsonLd.raw({
      '@context': 'https://schema.org',
      '@type': 'BreadcrumbList',
      'itemListElement': [
        for (var i = 0; i < items.length; i++)
          {
            '@type': 'ListItem',
            'position': i + 1,
            'name': items[i].name,
            'item': items[i].url,
          },
      ],
    });
  }
}
