import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:seo_seed/seo_seed.dart';
import 'package:seo_seed_go_router/seo_seed_go_router.dart';

/// Declared once; the app builds its router from this list, and seo_seed reads
/// the same list.
List<RouteBase> appRoutes() => [
  SeoGoRoute(
    path: '/pricing',
    builder: (context, state) => const Placeholder(),
    seoMetadata: (_) =>
        const SeoMetadata(title: 'Pricing', description: 'Simple pricing.'),
    seoContent: (_, b) => b.h1('Simple pricing'),
  ),
  SeoGoRoute(
    path: '/post/:slug',
    builder: (context, state) => Text(state.pathParameters['slug'] ?? ''),
    seoParams: () async => [const SeoParams({'slug': 'splitting-rent-fairly'})],
    seoMetadata: (p) => SeoMetadata(title: p['slug'], description: 'A post.'),
    seoContent: (p, b) => b.h1(p['slug']),
  ),
];

void main() {
  test('extracts SeoRoutes and converts :param -> [param]', () async {
    final routes = seoRoutesFrom(appRoutes(), const GoRouterSeo());
    expect(routes.map((r) => r.path), containsAll(['/pricing', '/post/[slug]']));

    final post = routes.firstWhere((r) => r.path == '/post/[slug]');
    expect(post.isDynamic, isTrue);
    expect(await post.resolveParams(), hasLength(1));
  });

  test('goPathToSeoPath converts colon params', () {
    expect(goPathToSeoPath('/a/:b/c/:d'), '/a/[b]/c/[d]');
  });
}
