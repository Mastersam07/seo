import 'dart:async';

import 'metadata.dart';
import 'node.dart';
import 'params.dart';
import 'route.dart';

/// A pure-Dart declaration of a route's path and SEO, so it can be shared
/// between your app's router and the build tool without either restating it.
///
/// A router adapter (e.g. `seo_seed_go_router`) builds the router's routes from
/// a list of these; the build tool turns the same list into `SeoRoute`s via
/// [toSeoRoute]. Because it carries no widgets, a file of descriptors imports no
/// Flutter — so a plain `dart run` build tool can import it.
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
