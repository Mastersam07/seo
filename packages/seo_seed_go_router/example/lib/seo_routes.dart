import 'package:seo_seed/seo_seed.dart';

/// The single source of truth for the site's routes — pure Dart (no Flutter, no
/// go_router), so the build tool can import it and run with a plain `dart run`.
/// The app (main.dart) builds its go_router from these too, via `goRoutesFor`.
const posts = {
  'splitting-rent-fairly': 'Splitting rent fairly',
  'settling-up': 'Settling up made simple',
};

final seoRoutes = <SeoRouteDescriptor>[
  SeoRouteDescriptor(
    path: '/',
    metadata: (_) => const SeoMetadata(
      title: 'Sortd',
      description: 'Split bills, settle up, done.',
      canonical: '/',
      openGraph: OpenGraph(image: '/og/home.png'),
      twitter: TwitterCard(site: '@sortd'),
    ),
    content: (_, b) =>
        b.article([b.h1('Sortd'), b.p('Split bills, settle up, done.')]),
  ),
  SeoRouteDescriptor(
    path: '/pricing',
    metadata: (_) => const SeoMetadata(
      title: 'Pricing — Sortd',
      description: 'Free for personal groups.',
      canonical: '/pricing',
      openGraph: OpenGraph(image: '/og/pricing.png'),
      twitter: TwitterCard(site: '@sortd'),
    ),
    content: (_, b) => b.article([
      b.h1('Simple pricing'),
      b.p('Free for personal groups. Upgrade for receipt scanning.'),
    ]),
  ),
  SeoRouteDescriptor(
    path: '/post/[slug]',
    params: () async =>
        posts.keys.map((slug) => SeoParams({'slug': slug})).toList(),
    metadata: (p) => SeoMetadata(
      title: '${posts[p['slug']]} — Sortd',
      description: 'A Sortd post.',
      canonical: '/post/${p['slug']}',
      breadcrumbs: true,
      openGraph: OpenGraph(
        title: posts[p['slug']],
        type: 'article',
        image: '/og/post/${p['slug']}.png',
      ),
      twitter: const TwitterCard(site: '@sortd'),
    ),
    content: (p, b) => b.article([b.h1(posts[p['slug']] ?? '')]),
  ),
];
