import 'node.dart';

/// Escapes text content for safe insertion between tags.
String escapeHtml(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

/// Escapes a value for use inside a double-quoted attribute.
String escapeAttr(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

/// Serializes a list of nodes to an HTML string.
String serializeNodes(List<SeoNode> nodes) => nodes.map(serializeNode).join();

/// Serializes a single node to an HTML string.
String serializeNode(SeoNode node) => switch (node) {
  SeoText(:final value, :final raw) => raw ? value : escapeHtml(value),
  SeoElement(selfClosing: true, :final tag, :final attributes) =>
    '<$tag${_attrs(attributes)}>',
  SeoElement(:final tag, :final attributes, :final children) =>
    '<$tag${_attrs(attributes)}>${serializeNodes(children)}</$tag>',
};

String _attrs(Map<String, String> attributes) => attributes.entries
    .map((kv) => ' ${escapeAttr(kv.key)}="${escapeAttr(kv.value)}"')
    .join();
