/// kaisel adapter for [seo_seed](https://pub.dev/packages/seo_seed).
///
/// kaisel is a sealed-class router with **no path strings** — URLs live in a
/// [KaiselCodec] (`encode(route) -> Uri`). So it doesn't fit `seo_seed`'s
/// tree-walking adapter (there's no path table to walk). Instead you enumerate
/// the indexable route instances and let the codec supply each URL:
///
/// ```dart
/// final seoRoutes = kaiselSeoRoutes<AppRoute>(
///   codec: const AppCodec(),
///   routes: [const PricingRoute(), ...posts.map(PostRoute.new)],
///   metadata: (r) => switch (r) { ... },
///   content: (r, b) => switch (r) { ... },
/// );
/// ```
///
/// Because the routes are your sealed types, `metadata`/`content` receive them
/// fully typed. Depends only on `kaisel_core` (pure Dart), so it also runs in a
/// bare-VM build tool.
library;

import 'dart:async';

import 'package:kaisel_core/kaisel_core.dart';
import 'package:seo_seed/seo_seed.dart';

/// Builds a `SeoRoute` per indexable kaisel [routes] entry, taking each URL from
/// the [codec]. Each becomes a static route at its encoded path.
List<SeoRoute> kaiselSeoRoutes<R extends KaiselRoute>({
  required KaiselCodec<R> codec,
  required Iterable<R> routes,
  required FutureOr<SeoMetadata> Function(R) metadata,
  required FutureOr<SeoNode> Function(R, SeoHtml) content,
}) => [
  for (final route in routes)
    SeoRoute.static(
      path: codec.encode(route).path,
      metadata: () => metadata(route),
      content: (b) => content(route, b),
    ),
];
