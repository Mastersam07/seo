import 'package:web/web.dart' as web;

/// Web implementation: remove the crawler seed block and its inlined critical
/// CSS once the app has taken over, so neither the seeded text nor its styles
/// linger under the canvas.
///
/// Elements marked `data-seo-keep` (the hidden-seed build mode) are left in
/// place on purpose: they are already `display:none`, so users never see them,
/// and keeping them means a JS-rendering crawler still finds the content in the
/// rendered DOM.
void takeoverImpl() {
  final seeds = web.document.querySelectorAll(
    '#seo-seed:not([data-seo-keep]), #seo-seed-style:not([data-seo-keep])',
  );
  for (var i = seeds.length - 1; i >= 0; i--) {
    if (seeds.item(i) case final web.Element el) el.remove();
  }
}
