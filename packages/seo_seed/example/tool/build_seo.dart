import 'package:seo_seed/build.dart';

import 'package:seo_seed_example/seo_routes.dart';

/// Run after `flutter build web`:
///
///   dart run tool/build_seo.dart --output build/web --base-url https://sortd.app
void main(List<String> args) =>
    SeoBuilder(seoRoutes, defaultLocale: 'en').run(args);
