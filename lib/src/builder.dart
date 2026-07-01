import 'dart:io';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

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

        final page = injectPage(
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
}

/// Injects [head] and [seed] into the Flutter web [shell], returning the
/// finished page HTML.
///
/// Unlike naive string replacement, this parses the shell with `package:html`,
/// so it does not depend on the shell using lowercase `</head>`, a single
/// `<body>`, or a particular `<base>` form. It:
///
///  * forces the base href to [baseHref] (so nested pages load the app bundle
///    from the configured root), replacing any existing `<base>`;
///  * merges the head fragment, removing any shell tag it supersedes (title,
///    a `<meta>` of the same name/property, a `<link>` of the same rel) so a
///    page never ends up with a stale duplicate title or description;
///  * prepends the crawler seed block as the first child of `<body>`. It is
///    left in normal flow and visible (no `display:none`) so crawlers treat it
///    as real content; `SeoRuntime.takeover()` removes it once Flutter paints.
String injectPage(
  String shell, {
  required String head,
  required String seed,
  required String baseHref,
}) {
  final document = html.parse(shell);
  final headEl = document.head;
  final bodyEl = document.body;
  if (headEl == null || bodyEl == null) {
    throw StateError(
      'seo_seed: shell HTML is missing a <head> or <body>. '
      'Is this a valid `flutter build web` index.html?',
    );
  }

  _forceBaseHref(headEl, baseHref);

  for (final node in html.parseFragment(head).nodes.toList()) {
    if (node is Element) _removeSupersededTags(headEl, node);
    headEl.append(node);
  }

  final seedDiv = Element.tag('div')..attributes['id'] = 'seo-seed';
  seedDiv.nodes.addAll(html.parseFragment(seed).nodes);
  bodyEl.insertBefore(seedDiv, bodyEl.firstChild);

  return document.outerHtml;
}

/// Sets `<base href>` to [baseHref], replacing an existing `<base>` in place or
/// inserting one as the first head child when absent.
void _forceBaseHref(Element headEl, String baseHref) {
  if (headEl.querySelector('base') case final existing?) {
    existing.attributes['href'] = baseHref;
  } else {
    final base = Element.tag('base')..attributes['href'] = baseHref;
    headEl.insertBefore(base, headEl.firstChild);
  }
}

/// Removes any tag already in [headEl] that [incoming] is about to replace,
/// keyed by identity: `<title>`, a `<meta>` with the same `name`/`property`, or
/// a `<link>` with the same `rel`. Other tags are left untouched.
void _removeSupersededTags(Element headEl, Element incoming) {
  bool supersedes(Element existing) {
    if (existing.localName != incoming.localName) return false;
    return switch (incoming.localName) {
      'title' => true,
      'meta' => switch (incoming.attributes['name'] ??
          incoming.attributes['property']) {
        final id? =>
          (existing.attributes['name'] ?? existing.attributes['property']) ==
              id,
        null => false,
      },
      'link' => switch (incoming.attributes['rel']) {
        final rel? => existing.attributes['rel'] == rel,
        null => false,
      },
      _ => false,
    };
  }

  headEl.children.where(supersedes).toList().forEach((e) => e.remove());
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
