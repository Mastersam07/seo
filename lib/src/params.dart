/// The resolved URL parameters for a single generated page.
///
/// For a route with path `/post/[id]`, a page generated for post `abc123`
/// receives `SeoParams({'id': 'abc123'})`. Static routes receive
/// [SeoParams.empty].
///
/// For a localized route, the builder also sets [locale] on the params passed
/// to `metadata`/`content`, so callbacks can translate per locale.
class SeoParams {
  const SeoParams(this.values, {this.locale});

  final Map<String, String> values;

  /// The locale this page is being generated for (e.g. `en`, `fr`), or null on
  /// a non-localized route.
  final String? locale;

  static const SeoParams empty = SeoParams({});

  /// A copy of these params tagged with [locale].
  SeoParams withLocale(String locale) => SeoParams(values, locale: locale);

  /// Returns the value for [key], or throws a [StateError] naming the missing
  /// key. Missing params are almost always a mismatch between the route path
  /// and what `params()` returned, so failing loudly beats a silent null.
  String operator [](String key) {
    final v = values[key];
    if (v == null) {
      throw StateError(
        "SeoParams has no value for '$key'. "
        "Available keys: ${values.keys.join(', ')}.",
      );
    }
    return v;
  }

  /// Like [], but returns null instead of throwing when [key] is absent.
  String? maybe(String key) => values[key];

  @override
  String toString() =>
      'SeoParams($values${locale == null ? '' : ', locale: $locale'})';
}
