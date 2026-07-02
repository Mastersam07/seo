import 'package:web/web.dart' as web;

/// Web implementation: remove the crawler seed block and its inlined critical
/// CSS once the app has taken over, so neither the seeded text nor its styles
/// linger under the canvas.
void takeoverImpl() {
  for (final id in const ['seo-seed', 'seo-seed-style']) {
    web.document.getElementById(id)?.remove();
  }
}
