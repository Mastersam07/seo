import 'package:kaisel_core/kaisel_core.dart';
import 'package:seo_seed/seo_seed.dart';
import 'package:seo_seed_kaisel/seo_seed_kaisel.dart';
import 'package:test/test.dart';

sealed class AppRoute extends KaiselRoute {
  const AppRoute();
}

class PricingRoute extends AppRoute {
  const PricingRoute();
}

class PostRoute extends AppRoute {
  const PostRoute(this.slug);
  final String slug;
  @override
  List<Object?> get props => [slug];
}

class AppCodec implements KaiselCodec<AppRoute> {
  const AppCodec();

  @override
  Uri encode(AppRoute route) => switch (route) {
    PricingRoute() => Uri.parse('/pricing'),
    PostRoute(:final slug) => Uri.parse('/post/$slug'),
  };

  @override
  AppRoute? decode(Uri uri) => switch (uri.pathSegments) {
    ['pricing'] => const PricingRoute(),
    ['post', final slug] => PostRoute(slug),
    _ => null,
  };
}

void main() {
  test('maps sealed routes to URLs via the codec', () {
    final routes = kaiselSeoRoutes<AppRoute>(
      codec: const AppCodec(),
      routes: [const PricingRoute(), const PostRoute('splitting-rent-fairly')],
      metadata: (r) => switch (r) {
        PricingRoute() => const SeoMetadata(title: 'Pricing', description: 'd'),
        PostRoute(:final slug) => SeoMetadata(title: slug, description: 'd'),
      },
      content: (r, b) => switch (r) {
        PricingRoute() => b.h1('Pricing'),
        PostRoute(:final slug) => b.h1(slug),
      },
    );
    expect(routes.map((r) => r.path), [
      '/pricing',
      '/post/splitting-rent-fairly',
    ]);
  });
}
