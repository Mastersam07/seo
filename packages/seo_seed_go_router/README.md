# seo_seed_go_router

[go_router](https://pub.dev/packages/go_router) adapter for
[seo_seed](https://pub.dev/packages/seo_seed).

go_router routes carry Flutter widget builders, so a file that defines them
can't be imported by a plain-Dart build tool (`dart:ui` is absent). This adapter
is therefore **descriptor-first**: declare your routes once as pure-Dart
`SeoRouteDescriptor`s, build the go_router routes *from* them with `goRoutesFor`,
and feed the same descriptors to the build tool.

```dart
// seo_routes.dart — pure Dart, imported by both the app and the build tool
final routes = <SeoRouteDescriptor>[
  SeoRouteDescriptor(
    path: '/post/[slug]',
    params: () async => (await api.slugs()).map((s) => SeoParams({'slug': s})).toList(),
    metadata: (p) => SeoMetadata(title: p['slug'], description: '…', canonical: '/post/${p['slug']}'),
    content: (p, b) => b.article([b.h1(p['slug'])]),
  ),
];

// main.dart — the app
GoRouter(routes: goRoutesFor(routes, (context, state, d) => screenFor(d, state)));

// tool/build_seo.dart — plain `dart run`
SeoBuilder([for (final d in routes) d.toSeoRoute()]).run(args);
```

The path lives once (in the descriptor); the app supplies only the screen, and
the build tool generates the SEO with `dart run` — no Flutter runtime needed.

See [`example/`](example) for a complete, runnable app.
