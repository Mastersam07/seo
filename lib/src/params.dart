/// The resolved URL parameters for a single generated page.
///
/// For a route with path `/post/[id]`, a page generated for post `abc123`
/// receives `SeoParams({'id': 'abc123'})`. Static routes receive
/// [SeoParams.empty].
class SeoParams {
  const SeoParams(this.values);

  final Map<String, String> values;

  static const SeoParams empty = SeoParams({});

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
  String toString() => 'SeoParams($values)';
}
