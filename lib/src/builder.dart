import 'dart:convert';
import 'dart:io';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import 'cache.dart';
import 'head.dart';
import 'json_ld.dart';
import 'locale.dart';
import 'metadata.dart';
import 'node.dart';
import 'paths.dart';
import 'robots.dart';
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
  SeoBuilder(
    this.routes, {
    this.defaultLocale,
    this.localeStrategy = const PathPrefixLocales(),
  });

  final List<SeoRoute> routes;

  /// The locale whose URL is used for the `hreflang="x-default"` alternate. When
  /// null, the first of a route's [SeoRoute.locales] is used.
  final String? defaultLocale;

  /// How a locale maps to a URL/path. Defaults to [PathPrefixLocales]
  /// (`/fr/pricing`).
  final SeoLocaleStrategy localeStrategy;

  /// Generates every page, writes the sitemap, and reports the outcome.
  ///
  /// Failures do not abort the run or throw: each is caught, attributed to its
  /// route, and collected in the returned [SeoBuildResult]. On any failure the
  /// process exit code is set to a non-zero value and a machine-readable JSON
  /// summary is written to stderr, so the generator fails a CI pipeline cleanly
  /// instead of crashing with a stack trace or exiting 0 with broken output.
  Future<SeoBuildResult> run(List<String> args) async {
    final (:output, :baseHref, :baseUrl, :dryRun, :verbose, :incremental) =
        _parseOptions(args);
    final shellFile = File('$output/index.html');
    if (!shellFile.existsSync()) {
      final result = SeoBuildResult(
        output: output,
        pageCount: 0,
        failures: [
          SeoBuildFailure(
            route: '(shell)',
            message:
                'shell not found at ${shellFile.path}. '
                'Run `flutter build web` first, or pass --output.',
          ),
        ],
      );
      _report(result, hasSitemap: false, dryRun: dryRun, exit: 2);
      return result;
    }
    final shell = shellFile.readAsStringSync();

    // When --base-href is omitted, inherit whatever `flutter build web` already
    // baked into the shell, so a subpath configured only at build time is not
    // silently reverted to root. An explicit flag wins, but warn if it conflicts
    // with the shell.
    final shellBaseHref = _shellBaseHref(shell);
    final effectiveBaseHref = baseHref ?? shellBaseHref;
    if (baseHref != null && baseHref != shellBaseHref) {
      stderr.writeln(
        'seo_seed: --base-href "$baseHref" does not match the shell\'s '
        '<base href="$shellBaseHref"> from `flutter build web`. '
        'Using "$baseHref" — make sure the two agree or the app will not boot.',
      );
    }

    final siteBase = switch (baseUrl) {
      final url? => _siteBase(url, effectiveBaseHref),
      null => null,
    };

    final cacheFile = File('$output/.seo_seed_cache.json');
    final cache = incremental
        ? SeoBuildCache.load(
            cacheFile,
            contentHash(
              jsonEncode([
                shell,
                effectiveBaseHref,
                siteBase ?? '',
                defaultLocale ?? '',
                localeStrategy.runtimeType.toString(),
              ]),
            ),
          )
        : null;

    var pageCount = 0;
    var skipped = 0;
    final failures = <SeoBuildFailure>[];
    final sitemap = siteBase == null
        ? null
        : SitemapShardWriter(
            siteBase: siteBase,
            write: (name, content) {
              if (!dryRun) File('$output/$name').writeAsStringSync(content);
            },
          );
    for (final route in routes) {
      final locales = route.locales.isEmpty
          ? const <String?>[null]
          : route.locales;
      try {
        await for (final baseParams in route.resolveParamsStream()) {
          for (final locale in locales) {
            final params = switch (locale) {
              final l? => baseParams.withLocale(l),
              null => baseParams,
            };
            try {
              // Cheap path/URL work first (no metadata/content), so an unchanged
              // page can be skipped without the expensive callbacks.
              final routePath = route.resolvePath(params);
              final pagePath = switch (locale) {
                final l? => localeStrategy.pathFor(l, routePath),
                null => routePath,
              };
              final dir = _pageDir(output, pagePath);
              final file = '$dir/index.html';

              if (cache != null &&
                  cache.unchangedByVersion(pagePath, params.version) &&
                  File(file).existsSync()) {
                cache.carryForward(pagePath);
                if (cache.sitemapFor(pagePath) case final sm?) {
                  sitemap?.add(_sitemapEntryFromJson(sm));
                }
                skipped++;
                if (verbose) stdout.writeln('  skipped (unchanged) $file');
                continue;
              }

              final pageUrl = switch (siteBase) {
                final base? => switch (locale) {
                  final l? => localeStrategy.urlFor(l, routePath, base),
                  null => canonicalizeUrl(resolveUrl(routePath, base)),
                },
                null => null,
              };

              var alternates = const <String, String>{};
              String? xDefault;
              if (locale != null && siteBase != null) {
                alternates = {
                  for (final l in route.locales)
                    l: localeStrategy.urlFor(l, routePath, siteBase),
                };
                final dflt = switch (defaultLocale) {
                  final d? when route.locales.contains(d) => d,
                  _ => route.locales.first,
                };
                xDefault = localeStrategy.urlFor(dflt, routePath, siteBase);
              }

              final meta = await route.metadataFor(params);
              final node = await route.contentFor(params, const SeoHtml());
              final page = injectPage(
                shell,
                head: renderHead(
                  meta,
                  siteBase: siteBase,
                  extraJsonLd: [
                    if (meta.breadcrumbs)
                      SeoJsonLd.breadcrumbTrail(path: pagePath, base: siteBase),
                  ],
                  alternates: alternates,
                  xDefault: xDefault,
                  selfCanonical: locale == null ? null : pageUrl,
                ),
                seed: serializeNode(node),
                baseHref: effectiveBaseHref,
              );

              SitemapEntry? entry;
              if (pageUrl case final loc? when meta.indexable) {
                final sm = meta.sitemap;
                entry = (
                  loc: loc,
                  lastmod: sm?.lastmod,
                  changeFreq: sm?.changeFreq,
                  priority: sm?.priority,
                  images: [
                    for (final image in sm?.images ?? const <String>[])
                      resolveUrl(image, siteBase),
                  ],
                  alternates: alternates,
                );
                sitemap?.add(entry);
              }

              final hash = contentHash(page);
              final unchangedWrite =
                  cache != null &&
                  cache.unchangedByHash(pagePath, hash) &&
                  File(file).existsSync();
              if (!dryRun && !unchangedWrite) {
                Directory(dir).createSync(recursive: true);
                File(file).writeAsStringSync(page);
              }
              cache?.record(
                pagePath,
                version: params.version,
                hash: hash,
                sitemap: entry == null ? null : _sitemapEntryToJson(entry),
              );
              pageCount++;
              if (verbose) {
                final action = dryRun
                    ? 'would write'
                    : (unchangedWrite ? 'unchanged' : 'wrote');
                stdout.writeln('  $action $file');
              }
            } catch (e) {
              failures.add(
                SeoBuildFailure(
                  route: route.path,
                  params: params.values,
                  message: '$e',
                ),
              );
            }
          }
        }
      } catch (e) {
        failures.add(SeoBuildFailure(route: route.path, message: '$e'));
      }
    }

    if (siteBase case final base?) {
      try {
        sitemap?.finish();
        if (!dryRun) {
          File(
            '$output/robots.txt',
          ).writeAsStringSync(renderRobots('$base/sitemap.xml'));
        }
      } catch (e) {
        failures.add(SeoBuildFailure(route: '(sitemap)', message: '$e'));
      }
    }

    if (cache != null && !dryRun) cache.save(cacheFile);

    final result = SeoBuildResult(
      output: output,
      pageCount: pageCount,
      skipped: skipped,
      failures: failures,
    );
    _report(result, hasSitemap: siteBase != null, dryRun: dryRun, exit: 1);
    return result;
  }

  /// Prints a success line, or a machine-readable failure summary plus a
  /// non-zero [exit] code when [result] has failures.
  void _report(
    SeoBuildResult result, {
    required bool hasSitemap,
    required bool dryRun,
    required int exit,
  }) {
    if (result.ok) {
      final prefix = dryRun
          ? 'seo_seed: [dry run] would generate'
          : 'seo_seed: generated';
      final skipped = result.skipped > 0
          ? ' (skipped ${result.skipped} unchanged)'
          : '';
      final extras = hasSitemap ? ' + sitemap.xml + robots.txt' : '';
      stdout.writeln(
        '$prefix ${result.pageCount} page(s)$skipped$extras in ${result.output}',
      );
      return;
    }
    stderr.writeln(
      'seo_seed: build failed with ${result.failures.length} error(s):',
    );
    stderr.writeln(const JsonEncoder.withIndent('  ').convert(result.toJson()));
    exitCode = exit;
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

/// The outcome of a [SeoBuilder.run]: how many pages were written and which
/// routes failed. [ok] is true when nothing failed. [toJson] gives the
/// machine-readable summary the CLI prints to stderr on failure.
class SeoBuildResult {
  SeoBuildResult({
    required this.output,
    required this.pageCount,
    this.skipped = 0,
    required this.failures,
  });

  final String output;
  final int pageCount;

  /// Pages skipped because they were unchanged since the last `--incremental`
  /// build.
  final int skipped;
  final List<SeoBuildFailure> failures;

  bool get ok => failures.isEmpty;

  Map<String, Object?> toJson() => {
    'ok': ok,
    'output': output,
    'pages': pageCount,
    'skipped': skipped,
    'failures': [for (final f in failures) f.toJson()],
  };
}

/// One failed route (and the params it was building, if any) with its error.
class SeoBuildFailure {
  SeoBuildFailure({required this.route, this.params, required this.message});

  final String route;
  final Map<String, String>? params;
  final String message;

  Map<String, Object?> toJson() => {
    'route': route,
    'params': ?params,
    'message': message,
  };
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
/// a `<link>` with the same `rel` and `hreflang`. Other tags are left untouched.
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
      // Match on rel AND hreflang, so a page's many `rel="alternate"` locale
      // links coexist (they differ only by hreflang) while a single
      // `rel="canonical"` still supersedes.
      'link' => switch (incoming.attributes['rel']) {
        final rel? =>
          existing.attributes['rel'] == rel &&
              existing.attributes['hreflang'] ==
                  incoming.attributes['hreflang'],
        null => false,
      },
      _ => false,
    };
  }

  headEl.children.where(supersedes).toList().forEach((e) => e.remove());
}

Map<String, Object?> _sitemapEntryToJson(SitemapEntry e) => {
  'loc': e.loc,
  'lastmod': e.lastmod?.toIso8601String(),
  'changeFreq': e.changeFreq?.name,
  'priority': e.priority,
  'images': e.images,
  'alternates': e.alternates,
};

SitemapEntry _sitemapEntryFromJson(Map<String, Object?> j) => (
  loc: j['loc'] as String,
  lastmod: switch (j['lastmod']) {
    final s? => DateTime.parse(s as String),
    null => null,
  },
  changeFreq: switch (j['changeFreq']) {
    final s? => SeoChangeFreq.values.byName(s as String),
    null => null,
  },
  priority: (j['priority'] as num?)?.toDouble(),
  images: (j['images'] as List<Object?>).cast<String>(),
  alternates: (j['alternates'] as Map<String, Object?>).cast<String, String>(),
);

/// The site base for absolute URLs: the origin plus the base-href path prefix,
/// so a page under `/app/` lists as `https://host/app/pricing`, not `/pricing`.
/// A root `/` base href contributes no prefix.
String _siteBase(String baseUrl, String baseHref) {
  final origin = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final prefix = baseHref.replaceAll(RegExp(r'^/+|/+$'), '');
  return prefix.isEmpty ? origin : '$origin/$prefix';
}

/// Reads the `<base href>` already present in the shell, normalized to end with
/// a slash. Defaults to `/` when the shell declares none.
String _shellBaseHref(String shell) {
  final href = html.parse(shell).querySelector('base')?.attributes['href'];
  if (href == null || href.isEmpty) return '/';
  return href.endsWith('/') ? href : '$href/';
}

typedef _Options = ({
  String output,
  String? baseHref,
  String? baseUrl,
  bool dryRun,
  bool verbose,
  bool incremental,
});

_Options _parseOptions(List<String> args) {
  var output = 'build/web';
  String? baseHref;
  String? baseUrl;
  var dryRun = false;
  var verbose = false;
  var incremental = false;

  for (var i = 0; i < args.length; i++) {
    String next() => (i + 1 < args.length) ? args[++i] : '';
    switch (args[i]) {
      case '--output' || '-o':
        output = next();
      case '--base-href':
        baseHref = next();
      case '--base-url':
        baseUrl = next();
      case '--dry-run':
        dryRun = true;
      case '--verbose' || '-v':
        verbose = true;
      case '--incremental':
        incremental = true;
    }
  }

  if (baseHref != null && !baseHref.endsWith('/')) baseHref = '$baseHref/';
  output = output.replaceAll(RegExp(r'/+$'), '');
  return (
    output: output,
    baseHref: baseHref,
    baseUrl: baseUrl,
    dryRun: dryRun,
    verbose: verbose,
    incremental: incremental,
  );
}
