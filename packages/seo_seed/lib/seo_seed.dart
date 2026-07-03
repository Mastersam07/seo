/// Opt-in, per-route SEO for Flutter web: seed real head metadata and crawler
/// content into static HTML at build time, then let the Flutter app take over.
///
/// See the README for the full flow. In brief:
///  * Declare indexable routes as [SeoRoute] values.
///  * Generate one static `index.html` per page with [SeoBuilder] after
///    `flutter build web`.
///  * Call [SeoRuntime.takeover] once in `main` to remove the seed on web.
library;

export 'runtime.dart' show SeoRuntime;
export 'src/params.dart';
export 'src/metadata.dart';
export 'src/json_ld.dart';
export 'src/locale.dart';
export 'src/node.dart' show SeoNode, SeoElement, SeoText, SeoHtml;
export 'src/route.dart';
export 'src/router.dart';
export 'src/builder.dart';
export 'src/renderer.dart';
