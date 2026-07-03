import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:seo_seed/seo_seed.dart';
import 'package:seo_seed_go_router/seo_seed_go_router.dart';

/// Stand-in data layer, shared by the widgets and the SEO builders.
const posts = {
  'splitting-rent-fairly': 'Splitting rent fairly',
  'settling-up': 'Settling up made simple',
};

/// The routes, declared once. The app builds its `GoRouter` from this list, and
/// the build tool feeds the same list to seo_seed via [GoRouterSeo].
List<RouteBase> appRoutes() => [
  SeoGoRoute(
    path: '/',
    builder: (context, state) => const _HomeScreen(),
    seoMetadata: (_) => const SeoMetadata(
      title: 'Sortd',
      description: 'Split bills, settle up, done.',
      canonical: '/',
    ),
    seoContent: (_, b) => b.article([
      b.h1('Sortd'),
      b.p('Split bills, settle up, done.'),
    ]),
  ),
  SeoGoRoute(
    path: '/pricing',
    builder: (context, state) => const _PricingScreen(),
    seoMetadata: (_) => const SeoMetadata(
      title: 'Pricing — Sortd',
      description: 'Free for personal groups.',
      canonical: '/pricing',
    ),
    seoContent: (_, b) => b.article([
      b.h1('Simple pricing'),
      b.p('Free for personal groups. Upgrade for receipt scanning.'),
    ]),
  ),
  SeoGoRoute(
    path: '/post/:slug',
    builder: (context, state) =>
        _PostScreen(slug: state.pathParameters['slug'] ?? ''),
    seoParams: () async =>
        posts.keys.map((slug) => SeoParams({'slug': slug})).toList(),
    seoMetadata: (p) => SeoMetadata(
      title: '${posts[p['slug']]} — Sortd',
      description: 'A Sortd post.',
      canonical: '/post/${p['slug']}',
      breadcrumbs: true,
    ),
    seoContent: (p, b) => b.article([b.h1(posts[p['slug']] ?? '')]),
  ),
];

class _HomeScreen extends StatelessWidget {
  const _HomeScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sortd')),
    body: const Center(child: Text('Split bills, settle up, done.')),
  );
}

class _PricingScreen extends StatelessWidget {
  const _PricingScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pricing')),
    body: const Center(child: Text('Free for personal groups.')),
  );
}

class _PostScreen extends StatelessWidget {
  const _PostScreen({required this.slug});
  final String slug;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(posts[slug] ?? 'Post')),
    body: Center(child: Text(posts[slug] ?? slug)),
  );
}
