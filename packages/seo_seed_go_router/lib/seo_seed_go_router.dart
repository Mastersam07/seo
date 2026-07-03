/// go_router adapter for [seo_seed](https://pub.dev/packages/seo_seed).
///
/// go_router routes carry Flutter widget builders, so a route file that defines
/// them can't be imported by a plain-Dart build tool (`dart:ui` is absent). So
/// this adapter is **descriptor-first**: declare your routes as pure-Dart
/// [SeoRouteDescriptor]s (shared with the build tool, which imports only them),
/// and build the go_router routes *from* those descriptors with [goRoutesFor]:
///
/// ```dart
/// // seo_routes.dart — pure Dart, imported by both the app and the build tool
/// final routes = <SeoRouteDescriptor>[
///   SeoRouteDescriptor(path: '/post/[slug]', params: ..., metadata: ..., content: ...),
/// ];
///
/// // main.dart — the app
/// GoRouter(routes: goRoutesFor(routes, (context, state, d) => screenFor(d, state)));
///
/// // tool/build_seo.dart — plain `dart run`
/// SeoBuilder([for (final d in routes) d.toSeoRoute()]).run(args);
/// ```
///
/// The path lives once (in the descriptor); the app supplies only the screen.
library;

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:seo_seed/seo_seed.dart';

/// Builds go_router routes from seo_seed [descriptors], converting each
/// descriptor's `[param]` path to go_router's `:param` and asking [screen] for
/// the widget. [extra] routes (shells, redirects, non-indexable pages) are
/// appended untouched.
List<RouteBase> goRoutesFor(
  Iterable<SeoRouteDescriptor> descriptors,
  Widget Function(
    BuildContext context,
    GoRouterState state,
    SeoRouteDescriptor descriptor,
  )
  screen, {
  List<RouteBase> extra = const [],
}) => [
  for (final descriptor in descriptors)
    GoRoute(
      path: seoPathToGoPath(descriptor.path),
      builder: (context, state) => screen(context, state, descriptor),
    ),
  ...extra,
];

/// Converts seo_seed path syntax to go_router's, e.g. `'/post/[slug]'` ->
/// `'/post/:slug'`.
String seoPathToGoPath(String seoPath) =>
    seoPath.replaceAllMapped(RegExp(r'\[(\w+)\]'), (m) => ':${m[1]}');
