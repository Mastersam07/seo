import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:seo_seed/runtime.dart';

import 'routes.dart';

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
      routerConfig: GoRouter(routes: appRoutes()),
    );
  }
}
