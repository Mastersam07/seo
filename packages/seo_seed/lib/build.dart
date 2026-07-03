/// The build-time surface: everything in `package:seo_seed/seo_seed.dart` (the
/// route/content model) plus the generator and the per-request renderer.
///
/// Import this from your build tool (`tool/build_seo.dart`) and any server that
/// runs [SeoRenderer]. Do **not** import it into your Flutter app — it pulls in
/// HTML/YAML parsing and the incremental cache, which are not dart2js-safe.
library;

export 'seo_seed.dart';
export 'src/builder.dart';
export 'src/renderer.dart';
