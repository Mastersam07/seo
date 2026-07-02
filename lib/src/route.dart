import 'dart:async';

import 'metadata.dart';
import 'node.dart';
import 'params.dart';
import 'paths.dart';

/// A single indexable route: its path pattern, the pages that exist for it,
/// and how to produce head metadata and crawler content for each page.
///
/// Construct with [SeoRoute.static] for a fixed path or [SeoRoute.dynamic] for
/// a parameterized path that fans out to many pages.
class SeoRoute {
  SeoRoute._({
    required this.path,
    required Future<List<SeoParams>> Function()? params,
    required Stream<SeoParams> Function()? paramsStream,
    required FutureOr<SeoMetadata> Function(SeoParams) metadata,
    required FutureOr<SeoNode> Function(SeoParams, SeoHtml) content,
    this.locales = const [],
  }) : _params = params,
       _paramsStream = paramsStream,
       _metadata = metadata,
       _content = content;

  /// The path pattern, e.g. `/pricing` or `/post/[id]`. Bracketed segments are
  /// substituted per page from the corresponding [SeoParams] value.
  final String path;

  /// Locales this route is generated in. Empty means a single, non-localized
  /// page. When set, the builder generates one page per locale (with reciprocal
  /// `hreflang` alternates) and tags each page's [SeoParams.locale] so
  /// `metadata`/`content` can translate.
  final List<String> locales;

  final Future<List<SeoParams>> Function()? _params;
  final Stream<SeoParams> Function()? _paramsStream;
  final FutureOr<SeoMetadata> Function(SeoParams) _metadata;
  final FutureOr<SeoNode> Function(SeoParams, SeoHtml) _content;

  /// A fixed page. [metadata] and [content] take no params.
  factory SeoRoute.static({
    required String path,
    required FutureOr<SeoMetadata> Function() metadata,
    required FutureOr<SeoNode> Function(SeoHtml) content,
  }) {
    return SeoRoute._(
      path: path,
      params: null,
      paramsStream: null,
      metadata: (_) => metadata(),
      content: (_, b) => content(b),
    );
  }

  /// A parameterized page. [params] enumerates which pages exist (the analogue
  /// of Expo's `generateStaticParams`); [metadata] and [content] receive the
  /// [SeoParams] for each page.
  ///
  /// For very large catalogs, pass [paramsStream] instead of [params] to yield
  /// pages lazily (e.g. as you page through an API), so the full list is never
  /// held in memory. Provide exactly one of [params] or [paramsStream].
  ///
  /// Pass [locales] to generate the route in several languages; each page's
  /// [SeoParams.locale] is set so the callbacks can translate. A localized
  /// fixed page is `params: () async => const [SeoParams.empty]` with [locales]
  /// set.
  factory SeoRoute.dynamic({
    required String path,
    Future<List<SeoParams>> Function()? params,
    Stream<SeoParams> Function()? paramsStream,
    required FutureOr<SeoMetadata> Function(SeoParams) metadata,
    required FutureOr<SeoNode> Function(SeoParams, SeoHtml) content,
    List<String> locales = const [],
  }) {
    if ((params == null) == (paramsStream == null)) {
      throw ArgumentError(
        'SeoRoute.dynamic needs exactly one of params or paramsStream.',
      );
    }
    return SeoRoute._(
      path: path,
      params: params,
      paramsStream: paramsStream,
      metadata: metadata,
      content: content,
      locales: locales,
    );
  }

  bool get isDynamic => _params != null || _paramsStream != null;

  /// The pages to generate, streamed. Static routes yield a single empty-params
  /// page; list-based routes yield each entry; streaming routes are passed
  /// through lazily.
  Stream<SeoParams> resolveParamsStream() async* {
    if (_paramsStream != null) {
      yield* _paramsStream();
    } else if (_params != null) {
      for (final p in await _params()) {
        yield p;
      }
    } else {
      yield SeoParams.empty;
    }
  }

  /// Collects [resolveParamsStream] into a list. Convenient for small routes and
  /// tests; the builder streams instead so it never materializes large sets.
  Future<List<SeoParams>> resolveParams() => resolveParamsStream().toList();

  Future<SeoMetadata> metadataFor(SeoParams p) async => _metadata(p);

  Future<SeoNode> contentFor(
    SeoParams p, [
    SeoHtml b = const SeoHtml(),
  ]) async => _content(p, b);

  static final _segment = RegExp(r'\[(\w+)\]');

  /// Substitutes bracketed segments in [path] with values from [p], e.g.
  /// `/post/[id]` with `{id: abc}` becomes `/post/abc`, in the package's
  /// canonical no-trailing-slash form (see [canonicalizeUrl]).
  ///
  /// Throws a [StateError] naming this route and the missing segment if [p]
  /// has no value for a `[segment]` in [path], so a mismatch between the path
  /// and what `params()` returned fails loudly at build time.
  String resolvePath(SeoParams p) {
    final substituted = path.replaceAllMapped(_segment, (m) {
      return switch (m.group(1)) {
        final key? => p.maybe(key) ?? _missingParam(key, p),
        null => m.group(0) ?? '',
      };
    });
    return canonicalizeUrl(substituted);
  }

  Never _missingParam(String key, SeoParams p) => throw StateError(
    "seo_seed: route '$path' has a '[$key]' segment but params() returned no "
    "'$key' value (keys: ${p.values.keys.join(', ')}). Every dynamic segment "
    'needs a matching key.',
  );
}
