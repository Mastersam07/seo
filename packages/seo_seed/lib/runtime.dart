/// The client-side entry point for seo_seed — import this into your Flutter app.
///
/// This is the runtime-only surface: it pulls in **none** of the build-time code
/// (the generator, HTML/YAML parsing, the incremental cache), so importing it
/// keeps your web app compiling cleanly (that code isn't dart2js-safe) and its
/// dependency graph small. The build tool imports the full
/// `package:seo_seed/seo_seed.dart` instead.
library;

import 'src/runtime/runtime.dart' as runtime;

/// Call once in `main` before `runApp`.
///
/// On web this removes the crawler seed block (`#seo-seed`) once invoked, so the
/// seeded content is not visible under the running app. On every other platform
/// it is a no-op, so it is safe to call unconditionally from shared `main` code.
class SeoRuntime {
  const SeoRuntime._();

  static void takeover() => runtime.takeoverImpl();
}
