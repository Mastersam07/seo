import 'package:flutter/material.dart';
import 'package:kaisel/kaisel.dart';
import 'package:seo_seed/runtime.dart';

import 'routes.dart';

/// The app's router — reuses the same [AppCodec] from routes.dart (wrapped for
/// the config layer), so its URLs match the SEO pages exactly.
final _config = KaiselRouterConfig<AppRoute>(
  initial: const Home(),
  codec: const StackToConfigCodec(KaiselSingleStackCodec(AppCodec())),
  builder: (context, route) => switch (route) {
    Home() => const _Screen('Sortd', 'Split bills, settle up, done.'),
    Pricing() => const _Screen('Pricing', 'Free for personal groups.'),
    Post(:final slug) => _Screen(posts[slug] ?? 'Post', posts[slug] ?? slug),
  },
);

void main() {
  SeoRuntime.takeover();
  runApp(MaterialApp.router(routerConfig: _config));
}

class _Screen extends StatelessWidget {
  const _Screen(this.title, this.body);
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(child: Text(body)),
  );
}
