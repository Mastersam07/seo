import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:seo_seed/seo_seed.dart';
import 'package:seo_seed_go_router/seo_seed_go_router.dart';

/// The single, pure-Dart source of truth for paths + SEO.
final descriptors = <SeoRouteDescriptor>[
  SeoRouteDescriptor(
    path: '/pricing',
    metadata: (_) => const SeoMetadata(title: 'Pricing', description: 'd'),
    content: (_, b) => b.h1('Pricing'),
  ),
  SeoRouteDescriptor(
    path: '/post/[slug]',
    params: () async => [
      const SeoParams({'slug': 'hi'}),
    ],
    metadata: (p) => SeoMetadata(title: p['slug'], description: 'd'),
    content: (p, b) => b.h1(p['slug']),
  ),
];

void main() {
  test('goRoutesFor builds GoRoutes with :param paths', () {
    final routes = goRoutesFor(
      descriptors,
      (context, state, d) => const SizedBox(),
    ).cast<GoRoute>();
    expect(routes.map((r) => r.path), ['/pricing', '/post/:slug']);
  });

  test('the same descriptors drive SEO via toSeoRoute', () async {
    final seoRoutes = [for (final d in descriptors) d.toSeoRoute()];
    expect(seoRoutes.map((r) => r.path), ['/pricing', '/post/[slug]']);
    final post = seoRoutes.firstWhere((r) => r.path == '/post/[slug]');
    expect(await post.resolveParams(), hasLength(1));
  });

  test('seoPathToGoPath converts bracket params', () {
    expect(seoPathToGoPath('/a/[b]/c/[d]'), '/a/:b/c/:d');
  });
}
