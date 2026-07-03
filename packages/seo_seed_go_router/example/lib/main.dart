import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:seo_seed/runtime.dart';
import 'package:seo_seed/seo_seed.dart' show SeoRouteDescriptor;
import 'package:seo_seed_go_router/seo_seed_go_router.dart';

import 'seo_routes.dart';

void main() {
  SeoRuntime.takeover();
  runApp(const SortdApp());
}

class SortdApp extends StatelessWidget {
  const SortdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Sortd',
      routerConfig: GoRouter(routes: goRoutesFor(seoRoutes, _screen)),
    );
  }

  static Widget _screen(
    BuildContext context,
    GoRouterState state,
    SeoRouteDescriptor descriptor,
  ) {
    final (title, body) = switch (descriptor.path) {
      '/' => ('Sortd', 'Split bills, settle up, done.'),
      '/pricing' => ('Pricing', 'Free for personal groups.'),
      _ => (
        posts[state.pathParameters['slug']] ?? 'Post',
        state.pathParameters['slug'] ?? '',
      ),
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(body)),
    );
  }
}
