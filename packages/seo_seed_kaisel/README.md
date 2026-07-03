# seo_seed_kaisel

[kaisel](https://pub.dev/packages/kaisel) adapter for
[seo_seed](https://pub.dev/packages/seo_seed).

kaisel is a sealed-class router with **no path strings** — URLs live in a
`KaiselCodec` (`encode(route) -> Uri`). Its routing core (`kaisel_core`) is pure
Dart, so your route definitions *are* importable by a plain-Dart build tool.
`kaiselSeoRoutes` enumerates the indexable route instances and lets the codec
supply each URL:

```dart
final seoRoutes = kaiselSeoRoutes<AppRoute>(
  codec: const AppCodec(),
  routes: [const Home(), const Pricing(), ...posts.map(Post.new)],
  metadata: (r) => switch (r) { ... },   // routes arrive fully typed
  content: (r, b) => switch (r) { ... },
);
```

This package depends only on `kaisel_core` (no Flutter), so its build tool runs
with a plain `dart run tool/build_seo.dart`. The app reuses the same
`KaiselCodec` (wrapped via `StackToConfigCodec(KaiselSingleStackCodec(...))`), so
the app's URLs and the generated SEO pages match exactly.

See [`example/`](example) for a complete, runnable app.
