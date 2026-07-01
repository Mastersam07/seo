import 'package:web/web.dart' as web;

/// Web implementation: remove the crawler seed block once the app has taken
/// over, so users never see the seeded text under the canvas.
void takeoverImpl() {
  final el = web.document.getElementById('seo-seed');
  el?.remove();
}
