import 'dart:io';

import 'package:yaml/yaml.dart';

/// Loads a `seo.yaml` config file into a plain map, or returns an empty map when
/// the file is absent. Its values become defaults for the CLI flags (so a flag
/// still overrides the file), letting per-run commands shrink to just what
/// varies.
///
/// Recognized keys: `output`, `base-url`, `base-href`, `incremental`,
/// `concurrency`.
Map<String, Object?> loadConfig(String path) {
  final file = File(path);
  if (!file.existsSync()) return const {};
  final yaml = loadYaml(file.readAsStringSync());
  if (yaml is! YamlMap) return const {};
  return {for (final entry in yaml.entries) '${entry.key}': entry.value};
}
