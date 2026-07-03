import 'dart:convert';
import 'dart:io';

/// A stable 64-bit FNV-1a hash of [s], as hex. Stable across runs and Dart
/// versions (unlike `String.hashCode`), which is what change detection needs.
String contentHash(String s) {
  var hash = 0xcbf29ce484222325;
  const mask = 0xffffffffffffffff;
  for (final byte in utf8.encode(s)) {
    hash = (hash ^ byte) & mask;
    hash = (hash * 0x100000001b3) & mask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

// [sitemap] is the page's serialized sitemap entry (null when non-indexable),
// replayed for skipped pages so the sitemap stays complete without recomputing.
typedef _Entry = ({
  String? version,
  String hash,
  Map<String, Object?>? sitemap,
});

/// The incremental-build manifest: a per-page record of the last build's
/// content, so unchanged pages can be skipped.
///
/// [buildKey] captures inputs shared by every page (the shell, base href, site
/// base). When it changes — e.g. a fresh `flutter build web` — the whole
/// previous manifest is discarded and everything regenerates.
class SeoBuildCache {
  SeoBuildCache._(this.buildKey, this._previous);

  final String buildKey;
  final Map<String, _Entry> _previous;
  final Map<String, _Entry> _next = {};

  /// Loads the manifest at [file] for a build identified by [buildKey]. A
  /// missing/corrupt file or a changed [buildKey] yields an empty previous set,
  /// so the next build regenerates everything.
  factory SeoBuildCache.load(File file, String buildKey) {
    if (!file.existsSync()) return SeoBuildCache._(buildKey, {});
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      if (json['buildKey'] != buildKey) return SeoBuildCache._(buildKey, {});
      final pages = (json['pages'] as Map<String, Object?>).map((path, value) {
        final entry = value as Map<String, Object?>;
        return MapEntry(path, (
          version: entry['version'] as String?,
          hash: entry['hash'] as String,
          sitemap: entry['sitemap'] as Map<String, Object?>?,
        ));
      });
      return SeoBuildCache._(buildKey, pages);
    } catch (_) {
      return SeoBuildCache._(buildKey, {});
    }
  }

  /// True when [path]'s previous [version] matches — the page can be skipped
  /// without recomputing it. Only meaningful when [version] is non-null.
  bool unchangedByVersion(String path, String? version) =>
      version != null && _previous[path]?.version == version;

  /// True when [path]'s already-rendered content hashes to the previous value —
  /// the file write can be skipped even though the page was recomputed.
  bool unchangedByHash(String path, String hash) =>
      _previous[path]?.hash == hash;

  /// Carries a skipped page's previous entry forward into the next manifest, so
  /// pruning (save only what this build touched) doesn't drop it.
  void carryForward(String path) {
    if (_previous[path] case final entry?) _next[path] = entry;
  }

  /// The previous build's sitemap entry for [path], replayed when the page is
  /// skipped so the sitemap stays complete.
  Map<String, Object?>? sitemapFor(String path) => _previous[path]?.sitemap;

  /// Records [path] as part of this build, so pages no longer generated are
  /// pruned from the next manifest.
  void record(
    String path, {
    String? version,
    required String hash,
    Map<String, Object?>? sitemap,
  }) => _next[path] = (version: version, hash: hash, sitemap: sitemap);

  void save(File file) {
    file.writeAsStringSync(
      jsonEncode({
        'buildKey': buildKey,
        'pages': {
          for (final MapEntry(:key, :value) in _next.entries)
            key: {
              'version': value.version,
              'hash': value.hash,
              'sitemap': value.sitemap,
            },
        },
      }),
    );
  }
}
