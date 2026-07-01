import 'dart:io';

import 'head.dart';
import 'node.dart';
import 'route.dart';
import 'serialize.dart';
import 'sitemap.dart';

/// Generates one static `index.html` per indexable page, seeding real head
/// metadata and crawler content into a copy of the Flutter web app shell.
///
/// Run this after `flutter build web`, pointing [run] at the build output:
///
/// ```dart
/// void main(List<String> args) => SeoBuilder(seoRoutes).run(args);
/// ```
///
/// ```
/// dart run tool/build_seo.dart --output build/web --base-url https://sortd.app
/// ```
class SeoBuilder {
  SeoBuilder(this.routes);

  final List<SeoRoute> routes;

  Future<void> run(List<String> args) async {
    final (:output, :baseHref, :baseUrl) = _parseOptions(args);
    final shellFile = File('$output/index.html');
    if (!shellFile.existsSync()) {
      stderr.writeln(
        'seo_seed: shell not found at ${shellFile.path}. '
        'Run `flutter build web` first, or pass --output.',
      );
      exitCode = 2;
      return;
    }
    final shell = shellFile.readAsStringSync();

    var pageCount = 0;
    for (final route in routes) {
      for (final params in await route.resolveParams()) {
        final meta = await route.metadataFor(params);
        final node = await route.contentFor(params, const SeoHtml());

        final page = _inject(
          shell,
          head: renderHead(meta),
          seed: serializeNode(node),
          baseHref: baseHref,
        );

        final dir = _pageDir(output, route.resolvePath(params));
        Directory(dir).createSync(recursive: true);
        File('$dir/index.html').writeAsStringSync(page);
        pageCount++;
      }
    }

    if (baseUrl case final url?) {
      final sitemap = await renderSitemap(routes, url);
      File('$output/sitemap.xml').writeAsStringSync(sitemap);
    }

    stdout.writeln(
      'seo_seed: generated $pageCount page(s)'
      '${baseUrl != null ? ' + sitemap.xml' : ''} in $output',
    );
  }

  /// Maps a route path to the output directory. `/` -> output root (which
  /// already holds the shell, so it is left alone unless a route explicitly
  /// targets `/`); `/post/abc` -> `output/post/abc`.
  String _pageDir(String output, String routePath) {
    final trimmed = routePath.replaceAll(RegExp(r'^/+|/+$'), '');
    if (trimmed.isEmpty) return output;
    return '$output/$trimmed';
  }

  /// Injects the head fragment, forces an absolute base href (so nested pages
  /// still load the app bundle from the site root), and prepends the crawler
  /// seed block inside the body.
  ///
  /// This targets the structure `flutter build web` produces: a single `<head>`
  /// and a `<body>` with an optional `<base href=...>`. It does not attempt to
  /// parse arbitrary HTML.
  String _inject(
    String shell, {
    required String head,
    required String seed,
    required String baseHref,
  }) {
    var out = shell;

    final baseTag = '<base href="$baseHref">';
    final baseRe = RegExp(r'<base\s+href="[^"]*"\s*/?>', caseSensitive: false);
    if (baseRe.hasMatch(out)) {
      out = out.replaceFirst(baseRe, baseTag);
    } else {
      out = out.replaceFirst('<head>', '<head>\n  $baseTag');
    }

    out = out.replaceFirst('</head>', '$head</head>');

    // Left in normal flow and visible (no display:none) so crawlers treat the
    // seed as real content rather than hidden text; SeoRuntime.takeover()
    // removes it once Flutter paints.
    final bodyOpen = RegExp(r'<body[^>]*>', caseSensitive: false);
    final seedBlock = '<div id="seo-seed">$seed</div>';
    out = out.replaceFirstMapped(bodyOpen, (m) => '${m.group(0)}\n$seedBlock');

    return out;
  }
}

typedef _Options = ({String output, String baseHref, String? baseUrl});

_Options _parseOptions(List<String> args) {
  var output = 'build/web';
  var baseHref = '/';
  String? baseUrl;

  for (var i = 0; i < args.length; i++) {
    String next() => (i + 1 < args.length) ? args[++i] : '';
    switch (args[i]) {
      case '--output' || '-o':
        output = next();
      case '--base-href':
        baseHref = next();
      case '--base-url':
        baseUrl = next();
    }
  }

  if (!baseHref.endsWith('/')) baseHref = '$baseHref/';
  output = output.replaceAll(RegExp(r'/+$'), '');
  return (output: output, baseHref: baseHref, baseUrl: baseUrl);
}
