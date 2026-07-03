/// go_router adapter for [seo_seed](https://pub.dev/packages/seo_seed).
///
/// go_router is a path-table router, so it fits `seo_seed`'s [SeoRouterAdapter]
/// directly: declare a route's SEO facet on a [SeoGoRoute] (next to its path,
/// written once), then extract the `SeoRoute`s with [GoRouterSeo]:
///
/// ```dart
/// final router = GoRouter(routes: appRoutes);
/// final seoRoutes = seoRoutesFrom(appRoutes, const GoRouterSeo());
/// ```
library;

import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:seo_seed/seo_seed.dart';

/// A [GoRoute] that also declares its SEO facet, so its path lives in one place.
class SeoGoRoute extends GoRoute {
  SeoGoRoute({
    required super.path, // go_router syntax, e.g. '/post/:slug'
    required super.builder,
    super.name,
    super.routes,
    super.redirect,
    required this.seoMetadata,
    required this.seoContent,
    this.seoParams,
    this.seoLocales = const [],
  });

  final FutureOr<SeoMetadata> Function(SeoParams) seoMetadata;
  final FutureOr<SeoNode> Function(SeoParams, SeoHtml) seoContent;
  final Future<List<SeoParams>> Function()? seoParams;
  final List<String> seoLocales;
}

/// Extracts `SeoRoute`s from a go_router route tree, reading the SEO facet off
/// each [SeoGoRoute] and converting `:param` to seo_seed's `[param]`.
class GoRouterSeo implements SeoRouterAdapter<RouteBase> {
  const GoRouterSeo();

  @override
  SeoRouteDescriptor? describe(RouteBase route) {
    if (route is! SeoGoRoute) return null;
    return SeoRouteDescriptor(
      path: goPathToSeoPath(route.path),
      params: route.seoParams,
      metadata: route.seoMetadata,
      content: route.seoContent,
      locales: route.seoLocales,
    );
  }

  @override
  Iterable<RouteBase> childrenOf(RouteBase route) => route.routes;
}

/// Converts go_router path syntax to seo_seed's, e.g. `'/post/:slug'` ->
/// `'/post/[slug]'`. Works for absolute paths; a nested relative go_router path
/// would need its parent path prepended.
String goPathToSeoPath(String goPath) =>
    goPath.replaceAllMapped(RegExp(r':(\w+)'), (m) => '[${m[1]}]');
