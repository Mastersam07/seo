import 'package:seo_seed/seo_seed.dart';

// A stand-in for your real data layer. In a real app these come from the same
// API client and models your Flutter widgets already use, which is what keeps
// the crawler content and the app content in sync at the data level.
class _Post {
  const _Post(this.slug, this.title, this.excerpt, this.body, this.publishedAt);
  final String slug;
  final String title;
  final String excerpt;
  final List<String> body;
  final DateTime publishedAt;
}

// DateTime is not const-constructible, so this sample list is `final`, not
// `const`. In a real app the date comes from your model (post.publishedAt).
final _posts = <_Post>[
  _Post(
    'splitting-rent-fairly',
    'Splitting rent fairly',
    'How to divide rent when rooms and incomes differ.',
    const [
      'Splitting rent evenly is rarely fair when rooms differ in size.',
      'Sortd lets you split by shares, so a larger room can carry more.',
    ],
    DateTime.utc(2026, 1, 15),
  ),
];

/// The list the build step and (optionally) your runtime read.
/// Only indexable routes belong here. Anything behind auth is absent.
final List<SeoRoute> seoRoutes = [
  SeoRoute.static(
    path: '/pricing',
    metadata: () => const SeoMetadata(
      title: 'Pricing - Sortd',
      description: 'Split bills, settle up, done. See Sortd pricing.',
      canonical: '/pricing',
      openGraph: OpenGraph(image: '/og/pricing.png'),
    ),
    content: (b) => b.article([
      b.h1('Simple pricing'),
      b.p(
        'Sortd is free for personal groups. '
        'Upgrade for receipt scanning and multi-currency.',
      ),
    ]),
  ),
  SeoRoute.dynamic(
    // Key the route on the slug so the generated URL, the canonical, and the
    // sitemap entry all agree on `/post/<slug>`.
    path: '/post/[slug]',
    params: () async => _posts.map((p) => SeoParams({'slug': p.slug})).toList(),
    metadata: (params) async {
      final post = _posts.firstWhere((p) => p.slug == params['slug']);
      return SeoMetadata(
        title: '${post.title} - Sortd',
        description: post.excerpt,
        canonical: '/post/${post.slug}',
        jsonLd: SeoJsonLd.article(
          headline: post.title,
          description: post.excerpt,
          datePublished: post.publishedAt,
        ),
      );
    },
    content: (params, b) async {
      final post = _posts.firstWhere((p) => p.slug == params['slug']);
      return b.article([
        b.h1(post.title),
        for (final para in post.body) b.p(para),
      ]);
    },
  ),
];
