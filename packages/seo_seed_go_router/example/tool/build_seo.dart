import 'package:seo_seed/build.dart';
import 'package:seo_seed_go_router/seo_seed_go_router.dart';

import 'package:seo_seed_go_router_example/routes.dart';

/// Generates SEO for the go_router routes: extract `SeoRoute`s from the same
/// route list the app uses, then run the builder.
///
///   flutter build web
///   dart run tool/build_seo.dart --base-url https://sortd.app
void main(List<String> args) =>
    SeoBuilder(seoRoutesFrom(appRoutes(), const GoRouterSeo())).run(args);
