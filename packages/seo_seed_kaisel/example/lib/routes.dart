import 'package:kaisel_core/kaisel_core.dart';
import 'package:seo_seed/seo_seed.dart';
import 'package:seo_seed_kaisel/seo_seed_kaisel.dart';

/// The routes and their URL codec — pure Dart (kaisel_core has no Flutter), so
/// the build tool imports this and runs with a plain `dart run`. The app
/// (main.dart) reuses the same sealed routes and the same [AppCodec].
const posts = {
  'splitting-rent-fairly': 'Splitting rent fairly',
  'settling-up': 'Settling up made simple',
};

sealed class AppRoute extends KaiselRoute {
  const AppRoute();
}

class Home extends AppRoute {
  const Home();
}

class Pricing extends AppRoute {
  const Pricing();
}

class Post extends AppRoute {
  const Post(this.slug);
  final String slug;
  @override
  List<Object?> get props => [slug];
}

/// The single source of URLs for these routes — used by SEO and by the app.
class AppCodec implements KaiselCodec<AppRoute> {
  const AppCodec();

  @override
  Uri encode(AppRoute route) => switch (route) {
    Home() => Uri.parse('/'),
    Pricing() => Uri.parse('/pricing'),
    Post(:final slug) => Uri.parse('/post/$slug'),
  };

  @override
  AppRoute? decode(Uri uri) => switch (uri.pathSegments) {
    [] => const Home(),
    ['pricing'] => const Pricing(),
    ['post', final slug] => Post(slug),
    _ => null,
  };
}

/// The indexable routes as `SeoRoute`s; the codec maps each to its URL.
List<SeoRoute> seoRoutes() => kaiselSeoRoutes<AppRoute>(
  codec: const AppCodec(),
  routes: [const Home(), const Pricing(), ...posts.keys.map(Post.new)],
  metadata: (r) => switch (r) {
    Home() => const SeoMetadata(
      title: 'Sortd',
      description: 'Split bills, settle up, done.',
      canonical: '/',
    ),
    Pricing() => const SeoMetadata(
      title: 'Pricing — Sortd',
      description: 'Free for personal groups.',
      canonical: '/pricing',
    ),
    Post(:final slug) => SeoMetadata(
      title: '${posts[slug]} — Sortd',
      description: 'A Sortd post.',
      canonical: '/post/$slug',
    ),
  },
  content: (r, b) => switch (r) {
    Home() => b.article([b.h1('Sortd'), b.p('Split bills, settle up, done.')]),
    Pricing() => b.article([
      b.h1('Simple pricing'),
      b.p('Free for personal groups.'),
    ]),
    Post(:final slug) => b.article([b.h1(posts[slug] ?? '')]),
  },
);
