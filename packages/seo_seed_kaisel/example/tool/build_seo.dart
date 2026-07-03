import 'package:seo_seed/build.dart';

import 'package:seo_seed_kaisel_example/routes.dart';

/// Plain `dart run` build tool. kaisel's routing core is pure Dart, so
/// routes.dart imports no Flutter — this runs in a bare Dart VM.
///
///   flutter build web
///   dart run tool/build_seo.dart --base-url https://sortd.app
void main(List<String> args) => SeoBuilder(seoRoutes()).run(args);
