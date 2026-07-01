/// Opt-in, per-route SEO for Flutter web: seed real head metadata and crawler
/// content into static HTML at build time, then let the Flutter app take over.
///
/// See the README for the full flow. In brief:
///  * Declare indexable routes as [SeoRoute] values.
///  * Generate one static `index.html` per page with [SeoBuilder] after
///    `flutter build web`.
///  * Call [SeoRuntime.takeover] once in `main` to remove the seed on web.
library;

import 'src/runtime/runtime.dart' as runtime;

export 'src/params.dart';
export 'src/metadata.dart';
export 'src/json_ld.dart';
export 'src/node.dart' show SeoNode, SeoElement, SeoText, SeoHtml;
export 'src/route.dart';
export 'src/builder.dart';

/// Client-side entry point. Call once in `main` before `runApp`.
///
/// On web this removes the crawler seed block (`#seo-seed`) once invoked, so
/// the seeded content is not visible under the running app. On every other
/// platform it is a no-op, so it is safe to call unconditionally from shared
/// `main` code.
class SeoRuntime {
  const SeoRuntime._();

  static void takeover() => runtime.takeoverImpl();
}
