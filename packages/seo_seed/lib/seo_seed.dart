/// Opt-in, per-route SEO for Flutter web: seed real head metadata and crawler
/// content into static HTML at build time, then let the Flutter app take over.
///
/// See the README for the full flow. In brief:
///  * Declare indexable routes as [SeoRoute] values.
///  * Generate one static `index.html` per page with [SeoBuilder] after
///    `flutter build web`.
///  * Call [SeoRuntime.takeover] once in `main` to remove the seed on web.
library;

// The app-safe surface: the route/content model plus the client runtime. It
// pulls in none of the build-time code, so it compiles to web cleanly and is
// what your app (route declarations, `SeoRuntime.takeover()`) imports. The
// build tool imports `package:seo_seed/build.dart`, which adds the generator.
export 'runtime.dart' show SeoRuntime;
export 'src/params.dart';
export 'src/metadata.dart';
export 'src/json_ld.dart';
export 'src/locale.dart';
export 'src/node.dart' show SeoNode, SeoElement, SeoText, SeoHtml;
export 'src/route.dart';
export 'src/router.dart';
