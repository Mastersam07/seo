# seo_seed

Opt-in, per-route SEO for Flutter web.

Flutter web paints your UI to a `<canvas>`, so crawlers and social scrapers see
no readable content. `seo_seed` fixes this for the routes you choose: it seeds
real head metadata and crawler-visible content into static HTML **at build
time**, then lets the Flutter app boot over it and remove the seed. Your mobile
build is untouched — generation runs only for web, only for the routes you
declare.

It's the same shape as Expo Router's static output (`output: "static"`) with
one extra piece: Expo renders the same component tree to both the app and the
crawler HTML, Flutter can't, so you supply the crawler content explicitly.

```dart
SeoRoute.static(
  path: '/pricing',
  metadata: () => const SeoMetadata(
    title: 'Pricing — Sortd',
    description: 'Split bills, settle up, done.',
    canonical: '/pricing',
    openGraph: OpenGraph(image: '/og/pricing.png'),
  ),
  content: (b) => b.article([
    b.h1('Simple pricing'),
    b.p('Free for personal groups. Upgrade for receipt scanning.'),
  ]),
);
```

## Features

- **Real head metadata** — title, description, canonical, Open Graph, Twitter
  cards, `robots`, and arbitrary meta, injected via a real HTML parser (no
  brittle string surgery, no duplicate tags).
- **Crawler-visible content** — a small, escape-by-default builder for the body
  content you want indexed (headings, lists, tables, blockquotes, figures…).
- **JSON-LD** — typed factories for Article, WebSite, Organization, Product,
  FAQPage and BreadcrumbList; multiple blocks per page.
- **Sitemap & robots.txt** — generated together, with `lastmod` / `changefreq`
  / `priority` / image entries, and `noindex` pages kept out of the sitemap.
- **Absolute canonical / OG URLs** — relative URLs are resolved against your
  site origin (and base-href prefix).
- **i18n / hreflang** — multi-locale routes with reciprocal `hreflang`
  alternates and a pluggable URL strategy (path prefix, subdomain, or domain).
- **CI-friendly** — a machine-readable result, non-zero exit on failure, and
  loud build-time errors.

> **Status:** 0.1, `seo_seed` is a working name. The core is analyzed and
> covered by tests; the API may still change before 1.0.

## Requirements

- Dart 3 / Flutter web.
- A `flutter build web` output to inject into (`build/web/index.html`).

## Install

```yaml
dependencies:
  seo_seed: ^0.1.0
```

`SeoRuntime.takeover()` is safe to call from shared `main` code — it is a no-op
off the web, so the dependency does not affect mobile or desktop builds.

## How it maps to Expo Router

| Expo Router | seo_seed |
| --- | --- |
| route file | `SeoRoute` |
| `Head` | `SeoMetadata` |
| `generateStaticParams` | `SeoRoute.dynamic(params: ...)` |
| component's rendered output | `content:` builder (the extra piece) |
| `output: "static"` | `SeoBuilder(...).run()` |
| `+html.tsx` shell | your `flutter build web` `index.html` |
| hydration | `SeoRuntime.takeover()` |

## 1. Declare routes

Only indexable routes belong here — anything behind auth is absent. Source
`metadata` and `content` from the same models your widgets use; the
presentation exists twice (a widget for users, a node tree for crawlers) but the
data stays a single source of truth.

```dart
import 'package:seo_seed/seo_seed.dart';

final seoRoutes = <SeoRoute>[
  SeoRoute.static(
    path: '/pricing',
    metadata: () => const SeoMetadata(
      title: 'Pricing — Sortd',
      description: 'Split bills, settle up, done.',
      canonical: '/pricing',
      openGraph: OpenGraph(image: '/og/pricing.png'),
    ),
    content: (b) => b.article([
      b.h1('Simple pricing'),
      b.p('Free for personal groups. Upgrade for receipt scanning.'),
    ]),
  ),

  SeoRoute.dynamic(
    path: '/post/[slug]',
    // Return one SeoParams per page. Page through your API if it paginates;
    // for very large catalogs, stream them instead (see Scaling large sites).
    params: () async => [
      for (final p in await api.allPosts()) SeoParams({'slug': p.slug}),
    ],
    metadata: (p) async {
      final post = await api.postBySlug(p['slug']);
      return SeoMetadata(
        title: '${post.title} — Sortd',
        description: post.excerpt,
        canonical: '/post/${post.slug}',
        jsonLd: [
          SeoJsonLd.article(
            headline: post.title,
            datePublished: post.publishedAt,
          ),
        ],
        breadcrumbs: true,
        sitemap: SeoSitemap(lastmod: post.updatedAt),
      );
    },
    content: (p, b) async {
      final post = await api.postBySlug(p['slug']);
      return b.article([
        b.h1(post.title),
        for (final para in post.body) b.p(para),
      ]);
    },
  ),
];
```

Key the route on the value that appears in the URL (here the slug), and make
`canonical` match it — the generated file path, canonical tag, and sitemap entry
should all agree.

## 2. Generate

```dart
// tool/build_seo.dart
import 'package:seo_seed/seo_seed.dart';
import 'package:your_app/seo_routes.dart';

void main(List<String> args) => SeoBuilder(seoRoutes).run(args);
```

```sh
flutter build web
dart run tool/build_seo.dart --output build/web --base-url https://sortd.app
```

This writes one `index.html` per page (`/post/abc` →
`build/web/post/abc/index.html`), sets the base href so nested pages still load
the app bundle, injects the head, prepends the crawler seed block, and — when
`--base-url` is given — writes `sitemap.xml` and `robots.txt`.

That's the whole flow. The common options:

| Flag | Meaning |
| --- | --- |
| `--output` (`-o`) | build output directory (default `build/web`) |
| `--base-url` | site origin, e.g. `https://sortd.app`; enables absolute URLs, sitemap, robots.txt |
| `--base-href` | override the shell's `<base href>` (see below) |

There are also `--dry-run` (preview without writing), `--verbose` (log each
page), `--build-web` (run `flutter build web` first, so it's one command), and —
for large sites — `--incremental` and `--concurrency` (see [Scaling large
sites](#scaling-large-sites-optional)), but you don't need any of them to start.

### Config file (optional)

Put shared options in a `seo.yaml` next to your build tool so per-run commands
shrink — CLI flags still override it:

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/seo_seed/seo_seed/main/seo.schema.json
base-url: https://sortd.app
incremental: true
concurrency: 8
```

Then `dart run tool/build_seo.dart` alone picks those up. Recognized keys:
`output`, `base-url`, `base-href`, `incremental`, `concurrency` (pass
`--config <path>` for a non-default location). A JSON Schema for editor
autocomplete/validation ships as [`seo.schema.json`](seo.schema.json).

For local iteration, just re-run the generator — `dart run` recompiles your
routes fresh each time, and `--incremental` keeps it fast. To auto-rerun on
save, wrap it in a generic file watcher (`watchexec`, `entr`).

## 3. Take over on the client

```dart
void main() {
  SeoRuntime.takeover(); // no-op off web; removes #seo-seed on web
  runApp(const MyApp());
}
```

## 4. Host config

You only pre-generate indexable routes. Every other path must fall back to the
app shell so the Flutter router can handle it — one SPA rewrite rule, e.g.
Firebase Hosting:

```json
{ "hosting": { "rewrites": [{ "source": "**", "destination": "/index.html" }] } }
```

Pre-generated files are served directly; everything else falls through to the
shell. `robots.txt` is only honored at the site root, so under subpath hosting
serve it from there.

## Content builder

`content:` receives an `SeoHtml` builder. Every method escapes its input, so
untrusted data is safe by default:

```dart
b.article([
  b.h1('Splitting rent fairly'),
  b.p('Rooms differ, so even splits rarely are.'),
  b.dataTable(
    headers: ['Plan', 'Price'],
    rows: [
      ['Free', '\$0'],
      ['Pro', '\$5/mo'],
    ],
  ),
  b.blockquote('Sortd made rent painless.', cite: 'https://example.com'),
  b.figure([b.img('/hero.png', alt: 'Sortd dashboard'), b.figcaption('The dashboard')]),
  b.descriptionList({'Founded': '2026', 'HQ': 'Remote'}),
]),
```

Also available: `h1`–`h3`, `p`, `ul`/`ol`/`li`, `dl`/`dt`/`dd`, `section`,
`nav`, `header`, `footer`, `span`, `strong`, `em`, `a`, `time`, and table
primitives (`table`/`thead`/`tbody`/`tr`/`th`/`td`). For a block of HTML you
have already produced and trust, use `b.raw(html)` — it is emitted verbatim, so
only pass markup you own.

## JSON-LD

`SeoMetadata.jsonLd` takes a list, so a page can carry several blocks:

```dart
jsonLd: [
  SeoJsonLd.article(headline: post.title, datePublished: post.publishedAt),
  SeoJsonLd.faq([(question: 'Is it free?', answer: 'Yes, for personal use.')]),
],
```

Factories: `article`, `website`, `organization`, `product`, `faq`,
`breadcrumb`, and `breadcrumbTrail` (a `BreadcrumbList` built from a route
path). For anything else, `SeoJsonLd.raw({...})`. Setting `breadcrumbs: true` on
the metadata makes the builder append a route-derived breadcrumb automatically.

## Sitemap & robots.txt

With `--base-url`, the builder writes both. Per-page hints come from
`SeoSitemap`:

```dart
sitemap: SeoSitemap(
  lastmod: post.updatedAt,
  changeFreq: SeoChangeFreq.weekly,
  priority: 0.8,
  images: ['/og/post.png'],
),
```

Pages whose metadata sets `robots: 'noindex'` (or `none`) are still generated —
so crawlers see the directive — but are left out of the sitemap, keeping the two
signals consistent. They are not `Disallow`ed, since a disallowed page can never
be crawled to see its `noindex`.

## Base href & subpath hosting

By default the generator **inherits the `<base href>` from the shell** — the one
`flutter build web` baked in. Configure a subpath once at build time and the
generator follows:

```sh
flutter build web --base-href /app/
dart run tool/build_seo.dart --output build/web --base-url https://example.com
# pages keep <base href="/app/">; canonical + sitemap use https://example.com/app/...
```

Pass `--base-href` to the generator only to override the shell; a value that
disagrees with the shell is honored but warned about, since the two must match
or the app will not boot.

## Internationalization (hreflang)

Give a route `locales` to generate it per language. Each page's
`SeoParams.locale` is set so `metadata`/`content` can translate, and the builder
emits reciprocal `hreflang` alternates (plus `x-default`), self-canonicalizes
each variant, and adds `xhtml:link` alternates to the sitemap.

```dart
SeoRoute.dynamic(
  path: '/about',
  locales: const ['en', 'fr'],
  params: () async => const [SeoParams.empty],
  metadata: (p) => SeoMetadata(
    title: p.locale == 'fr' ? 'À propos' : 'About',
    description: '…',
  ),
  content: (p, b) => b.h1(p.locale == 'fr' ? 'À propos' : 'About'),
);

// x-default → the default locale's URL
SeoBuilder(seoRoutes, defaultLocale: 'en').run(args);
```

How a locale maps to a URL is pluggable via `SeoLocaleStrategy`:

- `PathPrefixLocales()` (default) — `/fr/about`
- `SubdomainLocales(domain: 'example.com')` — `https://fr.example.com/about`
- `DomainLocales({'en': 'https://example.com', 'fr': 'https://example.fr'})`

```dart
SeoBuilder(seoRoutes, localeStrategy: const SubdomainLocales(domain: 'example.com'));
```

## Performance (Core Web Vitals)

A canvas app starts at a disadvantage: nothing meaningful paints until the
Flutter engine boots. Crawlable content is necessary but not sufficient —
ranking is also a speed function.

**Paint a styled hero before the engine boots.** The seed block is already the
first thing in `<body>` and visible, so it paints immediately — it just looks
unstyled. Give it critical CSS and it becomes a real, LCP-eligible hero. Target
`#seo-seed`; the seed *and* the style are removed on `takeover()`, so nothing
leaks into the running app:

```dart
SeoMetadata(
  title: 'Pricing — Sortd',
  description: 'Split bills, settle up, done.',
  criticalCss:
      '#seo-seed{max-width:640px;margin:0 auto;padding:24px;'
      'font:16px/1.5 system-ui,sans-serif}'
      '#seo-seed h1{font-size:28px}',
);
```

Keep it small and inline — the point is a fast first paint with no extra
round-trip. Because the hero *is* your crawler content, there's no second
representation to keep in sync.

**Then shrink the gap to interactivity:**

- Build with `flutter build web --wasm` where your plugins allow it — the
  skwasm renderer starts faster and is lighter than CanvasKit.
- Consider deferring engine load (e.g. boot on first interaction or after first
  paint) so the hero owns the early timeline; `flutter_bootstrap.js` is
  customizable for this.
- Keep the hero's largest element (usually the `h1`) meaningful, so LCP measures
  something real rather than a placeholder.

## Scaling large sites (optional)

**Most projects can ignore this.** A full rebuild of a landing page, pricing,
docs, and a few hundred blog posts takes seconds — just run the generator every
deploy. This section is only for large, data-driven catalogs (thousands to
millions of pages). Three things matter at that scale:

**Incremental — skip unchanged pages.** `--incremental` skips pages that haven't
changed. Attach a cheap change key to each page via `SeoParams.version` —
anything that changes when the page's content does, like the record's
`updatedAt`. On the next `--incremental` run, a page whose `version` matches the
last build is skipped **without** calling `metadata`/`content`, so only what
actually changed is re-rendered. A manifest (`.seo_seed_cache.json`) is kept in
the output dir; a fresh `flutter build web` or a config change invalidates it and
regenerates everything. Without a `version`, `--incremental` still avoids
rewriting unchanged files but can't skip the compute.

**Stream, don't materialize.** For a catalog that doesn't fit comfortably in
memory, use `paramsStream` instead of `params` so pages are yielded lazily as
you page through your API — the full list is never held at once:

```dart
SeoRoute.dynamic(
  path: '/post/[slug]',
  paramsStream: () async* {                  // page through your API, yield as you go
    String? cursor;
    do {
      final page = await api.posts(cursor: cursor);
      for (final p in page.items) {
        yield SeoParams({'slug': p.slug}, version: p.updatedAt.toIso8601String());
      }
      cursor = page.nextCursor;
    } while (cursor != null);
  },
  metadata: (p) async { /* ... */ },
  content: (p, b) async { /* ... */ },
);
```

**Overlap the API latency.** When `metadata`/`content` make an API call per
page, `--concurrency N` (default 1) keeps up to N pages in flight so their I/O
overlaps — the throughput lever for API-bound builds. It's cooperative
concurrency in a single isolate (overlapping waits, not multiple CPU cores), so
size N to your API's rate limits rather than your core count.

**Sitemaps shard automatically.** A single `sitemap.xml` is invalid past 50,000
URLs, so once you cross that the generator writes `sitemap-1.xml`,
`sitemap-2.xml`, … and turns `sitemap.xml` into a sitemap **index** over them
(robots.txt keeps pointing at `sitemap.xml`). Nothing to configure.

**And run the build against production, read-only data.** Whatever
`params`/`metadata`/`content` read at build time is what gets indexed — point
your API client at production (via env / `--dart-define`) in CI, don't deploy a
staging-built site, and use `--dry-run` to sanity-check the page count before a
real build.

## Server-side rendering (fresh per request)

Static generation bakes a snapshot. When content changes constantly (prices,
stock, personalized copy), render on demand instead: `SeoRenderer` runs the
**same** route callbacks and page assembly the builder uses — so static and SSR
output are byte-identical — but per request, so the data is always current.

```dart
final renderer = SeoRenderer(
  seoRoutes,
  shell: File('build/web/index.html').readAsStringSync(),
  siteBase: 'https://sortd.app',
);

// In your server/edge handler:
final html = await renderer.render(request.uri.path); // null → serve the shell
```

`render(path)` matches the URL to a route (including locale prefixes), returns
fresh HTML, or null when nothing matches or the route rejects the params (e.g.
an unknown id) — in which case you serve the app shell, exactly like the SPA
rewrite for static hosting. The core is framework-agnostic;
[`example/tool/serve_seo.dart`](example/tool/serve_seo.dart) is a runnable
`dart:io` server (SSR + static assets + SPA fallback), and the same one-liner
drops into an edge worker.

Use static generation by default (cheapest, cacheable); reach for SSR only for
the routes whose data can't be baked.

## Build output & CI

`run()` never crashes on a bad route: it catches each failure, attributes it to
its route, and returns a `SeoBuildResult`. On any failure it prints a
machine-readable JSON summary to stderr and sets a non-zero exit code (`2` = no
shell found, `1` = generation errors), so a broken build fails your pipeline
instead of shipping empty pages.

## What this does not do

- No widget-to-DOM rendering, and no scraping of the semantics tree. The content
  you want indexed is content you declare.
- No cloaking: the seed (static or server-rendered) must be a faithful subset of
  what users see.
