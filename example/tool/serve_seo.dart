import 'dart:io';

import 'package:seo_seed/seo_seed.dart';

import 'package:seo_seed_example/seo_routes.dart';

/// A minimal per-request SSR server, the runtime analogue of the static build.
///
/// For each request it renders the matching route *fresh* (so price/stock/etc.
/// are current), falling back to static assets and then the app shell — the same
/// shape as static files + an SPA rewrite, computed live.
///
///   flutter build web            # produces the shell + app bundle
///   dart run tool/serve_seo.dart  # serves it with live SEO
Future<void> main() async {
  final root = Directory('build/web');
  final shell = File('${root.path}/index.html').readAsStringSync();

  final renderer = SeoRenderer(
    seoRoutes,
    shell: shell,
    siteBase: 'https://sortd.app',
    defaultLocale: 'en',
  );

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
  stdout.writeln('serving http://localhost:8080 (SSR + SPA fallback)');

  await for (final request in server) {
    final path = request.uri.path;

    // 1. A matching route → render it fresh.
    if (await renderer.render(path) case final html?) {
      request.response
        ..headers.contentType = ContentType.html
        ..write(html);
      await request.response.close();
      continue;
    }

    // 2. A real static asset (the app bundle, images…) → serve the file.
    final file = File('${root.path}$path');
    if (path != '/' && file.existsSync()) {
      await request.response.addStream(file.openRead());
      await request.response.close();
      continue;
    }

    // 3. Anything else (in-app routes) → the shell; the Flutter app takes over.
    request.response
      ..headers.contentType = ContentType.html
      ..write(shell);
    await request.response.close();
  }
}
