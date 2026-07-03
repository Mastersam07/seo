import 'package:web/web.dart' as web;

/// Web implementation: remove the crawler seed block and its inlined critical
/// CSS once the app has taken over, so neither the seeded text nor its styles
/// linger under the canvas.
void takeoverImpl() {
  final seeds = web.document.querySelectorAll('#seo-seed, #seo-seed-style');
  for (var i = seeds.length - 1; i >= 0; i--) {
    if (seeds.item(i) case final web.Element el) el.remove();
  }
}
