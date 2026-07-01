import 'dart:async';

import 'metadata.dart';
import 'node.dart';
import 'params.dart';

/// A single indexable route: its path pattern, the pages that exist for it,
/// and how to produce head metadata and crawler content for each page.
///
/// Construct with [SeoRoute.static] for a fixed path or [SeoRoute.dynamic] for
/// a parameterized path that fans out to many pages.
class SeoRoute {
  SeoRoute._({
    required this.path,
    required Future<List<SeoParams>> Function()? params,
    required FutureOr<SeoMetadata> Function(SeoParams) metadata,
    required FutureOr<SeoNode> Function(SeoParams, SeoHtml) content,
  }) : _params = params,
       _metadata = metadata,
       _content = content;

  /// The path pattern, e.g. `/pricing` or `/post/[id]`. Bracketed segments are
  /// substituted per page from the corresponding [SeoParams] value.
  final String path;

  final Future<List<SeoParams>> Function()? _params;
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
      metadata: (_) => metadata(),
      content: (_, b) => content(b),
    );
  }

  /// A parameterized page. [params] enumerates which pages exist (the analogue
  /// of Expo's `generateStaticParams`); [metadata] and [content] receive the
  /// [SeoParams] for each page.
  factory SeoRoute.dynamic({
    required String path,
    required Future<List<SeoParams>> Function() params,
    required FutureOr<SeoMetadata> Function(SeoParams) metadata,
    required FutureOr<SeoNode> Function(SeoParams, SeoHtml) content,
  }) {
    return SeoRoute._(
      path: path,
      params: params,
      metadata: metadata,
      content: content,
    );
  }

  bool get isDynamic => _params != null;

  /// The set of pages to generate. Static routes yield a single empty-params
  /// page.
  Future<List<SeoParams>> resolveParams() async {
    if (_params == null) return const [SeoParams.empty];
    return _params();
  }

  Future<SeoMetadata> metadataFor(SeoParams p) async => _metadata(p);

  Future<SeoNode> contentFor(
    SeoParams p, [
    SeoHtml b = const SeoHtml(),
  ]) async => _content(p, b);

  static final _segment = RegExp(r'\[(\w+)\]');

  /// Substitutes bracketed segments in [path] with values from [p], e.g.
  /// `/post/[id]` with `{id: abc}` becomes `/post/abc`.
  String resolvePath(SeoParams p) {
    return path.replaceAllMapped(_segment, (m) {
      return switch (m.group(1)) {
        final key? => p[key],
        null => m.group(0) ?? '',
      };
    });
  }
}
