# seo_seed — monorepo

Opt-in, per-route SEO for Flutter web. This repository is a
[pub workspace](https://dart.dev/tools/pub/workspaces): the core package plus
router adapters and the demo app, sharing one lockfile and one `pub get`.

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
