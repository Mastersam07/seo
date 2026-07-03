import 'package:seo_seed/build.dart';

import 'package:seo_seed_go_router_example/seo_routes.dart';

/// Plain `dart run` build tool — it imports only the pure-Dart route
/// descriptors (no Flutter, no go_router), so it runs in a bare Dart VM.
///
///   flutter build web
///   dart run tool/build_seo.dart --base-url https://sortd.app
void main(List<String> args) =>
    SeoBuilder([for (final d in seoRoutes) d.toSeoRoute()]).run(args);
