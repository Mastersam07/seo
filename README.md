# seo_seed

Opt-in, per-route SEO for Flutter web.

Flutter web paints your UI to a `<canvas>`, so crawlers and social scrapers see
no readable content. `seo_seed` fixes this for the routes you choose by seeding
real head metadata and crawler content into static HTML **at build time**, then
letting the Flutter app boot over it. Your mobile build is untouched: the
generation runs only for web, and only for the routes you declare.

This is the same shape as Expo Router's static output (`output: "static"`), with
one extra piece. Expo renders the same component tree to both the app and the
crawler HTML. Flutter can't (sigh), so you supply the crawler content explicitly. That
one addition is the whole difference.