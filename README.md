# seo_seed — monorepo

Opt-in, per-route SEO for Flutter web. This repository is a
[pub workspace](https://dart.dev/tools/pub/workspaces): the core package plus
router adapters and the demo app, sharing one lockfile and one `pub get`.

## Status: a failed experiment — do not use in production

Being honest so nobody inherits false confidence: **this project did not
succeed, and I would not put it in front of traffic I cared about.** It is
archived here as a design study, not a dependency.

Why it failed:

- **Its one core claim was never proven.** The entire premise is "crawlers
  actually index the seeded content." The only test that proves that — deploy a
  page and check Google Search Console → URL Inspection to confirm the seeded
  title/description/body survive into what Google indexes — was **never run**.
  Everything green in this repo (unit tests, a headless-Chrome takeover check,
  `curl`/`grep`) is scaffolding *around* that test, not the test itself. An SEO
  tool whose crawler-visibility claim is unverified against a live crawl has not
  done its job.
- **The tests gave false comfort.** A five-minute real-browser smoke test found
  **two genuine bugs** — duplicate seed blocks and a non-idempotent build that
  accumulated stale content across runs — that **90 passing unit tests missed**.
  That is the most damning signal in the whole effort: the coverage did not
  catch real breakage, so the untested paths (SSR under load, i18n, sharded
  sitemaps at scale, the `package:web` runtime across browsers) should be
  assumed to hide more.
- **The default fights the purpose.** It ships `display:none` on your primary
  content by default. Search engines *discount* hidden content, and a page whose
  only crawlable text is a hidden seed is the strongest "hidden text" signal
  there is. A package named `seo_seed` whose out-of-box behavior undercuts
  ranking is working against itself.
- **It is remediation for a bad constraint, not a reason to accept it.** Where
  SEO matters most, the right move is not to seed a canvas app — it is to not
  ship the canvas. A web-native stack (Astro, Next, Jaspr, plain static HTML)
  emits real crawlable HTML for free. This package only makes sense in a narrow
  slot: you *already* have a large Flutter web app, one codebase you won't fork,
  and you need a subset of routes indexable. That slot is real but uncommon, and
  even there it is a compromise.

The friction and ceremony it adds (all of which a web-native stack avoids):

- You must run `flutter build web` first, then run a **separate** generator step
  over its output — a two-phase build to keep wired up in CI.
- A **three-way import split** (`runtime.dart` vs `seo_seed.dart` vs
  `build.dart`) that exists only because dart2js cannot represent the build
  tool's 64-bit cache literals. Import the wrong one and your web build breaks
  with an opaque error. This is the most likely thing a new user gets wrong.
- A mandatory **SPA fallback rewrite** in host config, or every non-generated
  route 404s.
- **Router restructuring** to a descriptor-first shape so a bare Dart VM can
  import your routes without booting Flutter — you rewrite how routes are
  declared to adopt this.
- Per-page **content builders you must hand-write and keep faithful** to what
  the app renders — a second representation of your content to maintain and keep
  in sync, forever.
- A build tool that **cannot import Flutter at all** (no `dart:ui` in a bare
  VM), so anything your route data touches must be pure Dart.

What it did get right, kept here as the design study: build-time seeding is the
correct approach for a canvas app (runtime JS injection is invisible to
non-rendering crawlers); the separation of build-time / runtime / model surfaces
is clean; the Expo Router `output: "static"` mapping is an honest framing. The
bones are fine. The proof is missing and the ergonomics are heavy — so it stays
a study, not a tool.

## Packages

| Package | What it is |
| --- | --- |
| [`packages/seo_seed`](packages/seo_seed) | The core — build-time static generation, per-request `SeoRenderer`, the router-agnostic adapter seam. **Start here** ([README](packages/seo_seed/README.md)). |
| [`packages/seo_seed_go_router`](packages/seo_seed_go_router) | go_router adapter — declare a route's SEO facet next to its path. |
| [`packages/seo_seed_kaisel`](packages/seo_seed_kaisel) | kaisel adapter — map sealed routes to SEO pages via the router's URL codec (pure Dart). |
| [`example`](packages/seo_seed/example) | A Flutter web app wired up with seo_seed. |

See [ROADMAP.md](ROADMAP.md) for status and direction.

## Working in the repo

```sh
dart pub get                 # once, at the root — resolves the whole workspace
dart test                    # from packages/seo_seed
flutter test                 # from an adapter package or example
```
