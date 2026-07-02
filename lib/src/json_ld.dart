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

  /// schema.org `BreadcrumbList` derived from a route [path], one item per
  /// cumulative path segment (plus a [home] root). Segment names default to a
  /// humanized form of the segment (`splitting-rent` -> `Splitting Rent`) and
  /// can be overridden per segment via [names]. When [base] is given item URLs
  /// are absolute; otherwise they are root-relative.
  factory SeoJsonLd.breadcrumbTrail({
    required String path,
    String? base,
    String home = 'Home',
    Map<String, String> names = const {},
  }) {
    final items = <({String name, String url})>[(name: home, url: base ?? '/')];
    var url = base ?? '';
    for (final segment in path.split('/').where((s) => s.isNotEmpty)) {
      url = '$url/$segment';
      items.add((name: names[segment] ?? _humanize(segment), url: url));
    }
    return SeoJsonLd.breadcrumb(items);
  }

  static String _humanize(String segment) => segment
      .split(RegExp(r'[-_]'))
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');

  /// schema.org `Organization`, typically emitted on a landing page.
  /// [sameAs] lists social/profile URLs that represent the same entity.
  factory SeoJsonLd.organization({
    required String name,
    required String url,
    String? logo,
    List<String> sameAs = const [],
  }) {
    return SeoJsonLd.raw({
      '@context': 'https://schema.org',
      '@type': 'Organization',
      'name': name,
      'url': url,
      'logo': ?logo,
      if (sameAs.isNotEmpty) 'sameAs': sameAs,
    });
  }

  /// schema.org `Product`. When [price] is set an `Offer` is included; prices
  /// are strings (e.g. `'9.99'`) to avoid floating-point rounding, and
  /// [availability] is a schema.org URL such as `https://schema.org/InStock`.
  factory SeoJsonLd.product({
    required String name,
    String? description,
    String? image,
    String? brand,
    String? sku,
    String? price,
    String? priceCurrency,
    String? availability,
    String? url,
  }) {
    return SeoJsonLd.raw({
      '@context': 'https://schema.org',
      '@type': 'Product',
      'name': name,
      'description': ?description,
      'image': ?image,
      if (brand case final b?) 'brand': {'@type': 'Brand', 'name': b},
      'sku': ?sku,
      'url': ?url,
      if (price case final p?)
        'offers': {
          '@type': 'Offer',
          'price': p,
          'priceCurrency': ?priceCurrency,
          'availability': ?availability,
          'url': ?url,
        },
    });
  }

  /// schema.org `FAQPage`. [items] is ordered question -> answer.
  factory SeoJsonLd.faq(List<({String question, String answer})> items) {
    return SeoJsonLd.raw({
      '@context': 'https://schema.org',
      '@type': 'FAQPage',
      'mainEntity': [
        for (final item in items)
          {
            '@type': 'Question',
            'name': item.question,
            'acceptedAnswer': {'@type': 'Answer', 'text': item.answer},
          },
      ],
    });
  }
}
