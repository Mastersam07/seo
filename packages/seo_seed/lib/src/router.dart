import 'dart:async';

import 'metadata.dart';
import 'node.dart';
import 'params.dart';
import 'route.dart';

/// The SEO facet of a route, declared once and attached to your router's own
/// route objects, so a route's path and params live in a single place instead
/// of being restated for `seo_seed`.
///
/// [metadata] and [content] mirror [SeoRoute.dynamic]. Provide [params] (or
/// [paramsStream]) for a route that fans out to many pages, or neither for a
/// fixed page. Set [locales] to generate the route per language.
class SeoRouteDescriptor {
  const SeoRouteDescriptor({
    required this.path,
    this.params,
    this.paramsStream,
    required this.metadata,
    required this.content,
    this.locales = const [],
  });

  final String path;
  final Future<List<SeoParams>> Function()? params;
  final Stream<SeoParams> Function()? paramsStream;
  final FutureOr<SeoMetadata> Function(SeoParams) metadata;
  final FutureOr<SeoNode> Function(SeoParams, SeoHtml) content;
  final List<String> locales;

  /// The equivalent [SeoRoute]. A descriptor with no params and no locales
  /// becomes a static route; anything else becomes a dynamic route (a localized
  /// fixed page defaults to a single empty-params page).
  SeoRoute toSeoRoute() {
    if (params == null && paramsStream == null && locales.isEmpty) {
      return SeoRoute.static(
        path: path,
        metadata: () => metadata(SeoParams.empty),
        content: (b) => content(SeoParams.empty, b),
      );
    }
    return SeoRoute.dynamic(
      path: path,
      params: paramsStream == null
          ? (params ?? () async => const [SeoParams.empty])
          : null,
      paramsStream: paramsStream,
      metadata: metadata,
      content: content,
      locales: locales,
    );
  }
}

/// Bridges an arbitrary router's route type [R] to `seo_seed`. Implement one
/// small adapter per router (go_router, auto_route, kaisel, a custom router):
/// say how to read a route's [SeoRouteDescriptor] and how to reach its nested
/// child routes. The core stays router-agnostic; [seoRoutesFrom] does the walk.
///
/// ```dart
/// class GoRouterSeo implements SeoRouterAdapter<RouteBase> {
///   const GoRouterSeo();
///   @override
///   SeoRouteDescriptor? describe(RouteBase r) =>
///       r is SeoGoRoute ? r.seo : null; // however you attach it
///   @override
///   Iterable<RouteBase> childrenOf(RouteBase r) =>
///       r is GoRoute ? r.routes : const [];
/// }
/// ```
abstract interface class SeoRouterAdapter<R> {
  /// The SEO descriptor for [route], or null when the route is not indexable.
  SeoRouteDescriptor? describe(R route);

  /// The nested child routes of [route] (empty for flat routers).
  Iterable<R> childrenOf(R route);
}

/// Walks [routes] (and their descendants) through [adapter], collecting a
/// [SeoRoute] for every route that carries an SEO descriptor.
List<SeoRoute> seoRoutesFrom<R>(
  Iterable<R> routes,
  SeoRouterAdapter<R> adapter,
) {
  final result = <SeoRoute>[];
  void walk(Iterable<R> rs) {
    for (final route in rs) {
      if (adapter.describe(route) case final descriptor?) {
        result.add(descriptor.toSeoRoute());
      }
      walk(adapter.childrenOf(route));
    }
  }

  walk(routes);
  return result;
}
