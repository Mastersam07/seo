import 'package:seo_seed/seo_seed.dart';
import 'package:seo_seed/src/serialize.dart';
import 'package:seo_seed/src/head.dart';
import 'package:test/test.dart';

void main() {
  const b = SeoHtml();

  group('serialize', () {
    test('escapes text content', () {
      final node = b.p('5 < 10 & "quotes"');
      expect(serializeNode(node), '<p>5 &lt; 10 &amp; "quotes"</p>');
    });

    test('escapes attribute values', () {
      final node = b.a('/x?a=1&b=2', 'link');
      expect(serializeNode(node), '<a href="/x?a=1&amp;b=2">link</a>');
    });

    test('raw is emitted verbatim', () {
      final node = b.raw('<em>bold</em>');
      expect(serializeNode(node), '<em>bold</em>');
    });

    test('nests children', () {
      final node = b.article([b.h1('Title'), b.p('Body')]);
      expect(
        serializeNode(node),
        '<article><h1>Title</h1><p>Body</p></article>',
      );
    });

    test('self-closing image', () {
      final node = b.img('/a.png', alt: 'a');
      expect(serializeNode(node), '<img src="/a.png" alt="a">');
    });

    test('mixed string and node children via list', () {
      final node = b.section([b.h2('H'), b.p('one'), b.p('two')]);
      expect(
        serializeNode(node),
        '<section><h2>H</h2><p>one</p><p>two</p></section>',
      );
    });

    test('string content becomes a single text child', () {
      expect(serializeNode(b.h1('Title')), '<h1>Title</h1>');
    });

    test('list of li built with a for-element', () {
      final node = b.ul([
        for (final s in ['a', 'b']) b.li(s),
      ]);
      expect(serializeNode(node), '<ul><li>a</li><li>b</li></ul>');
    });
  });

  group('resolvePath', () {
    test('substitutes a single param', () {
      final route = SeoRoute.dynamic(
        path: '/post/[id]',
        params: () async => [
          const SeoParams({'id': 'abc'}),
        ],
        metadata: (_) => const SeoMetadata(title: 't', description: 'd'),
        content: (_, b) => b.p('x'),
      );
      expect(route.resolvePath(const SeoParams({'id': 'abc'})), '/post/abc');
    });

    test('substitutes multiple params', () {
      final route = SeoRoute.dynamic(
        path: '/[year]/[slug]',
        params: () async => const [],
        metadata: (_) => const SeoMetadata(title: 't', description: 'd'),
        content: (_, b) => b.p('x'),
      );
      final resolved = route.resolvePath(
        const SeoParams({'year': '2026', 'slug': 'hello'}),
      );
      expect(resolved, '/2026/hello');
    });

    test('static route path is unchanged', () {
      final route = SeoRoute.static(
        path: '/pricing',
        metadata: () => const SeoMetadata(title: 't', description: 'd'),
        content: (b) => b.p('x'),
      );
      expect(route.resolvePath(SeoParams.empty), '/pricing');
    });
  });

  group('resolveParams', () {
    test('static route yields one empty-params page', () async {
      final route = SeoRoute.static(
        path: '/pricing',
        metadata: () => const SeoMetadata(title: 't', description: 'd'),
        content: (b) => b.p('x'),
      );
      final params = await route.resolveParams();
      expect(params, [SeoParams.empty]);
    });
  });

  group('renderHead', () {
    test('emits title, description, canonical', () {
      final head = renderHead(
        const SeoMetadata(
          title: 'Hello',
          description: 'A page',
          canonical: '/hello',
        ),
      );
      expect(head, contains('<title>Hello</title>'));
      expect(head, contains('name="description" content="A page"'));
      expect(head, contains('rel="canonical" href="/hello"'));
    });

    test('og title falls back to page title', () {
      final head = renderHead(
        const SeoMetadata(
          title: 'Hello',
          description: 'A page',
          openGraph: OpenGraph(image: '/og.png'),
        ),
      );
      expect(head, contains('property="og:title" content="Hello"'));
      expect(head, contains('property="og:image" content="/og.png"'));
    });

    test('json-ld closing tags are neutralized', () {
      final head = renderHead(
        SeoMetadata(
          title: 't',
          description: 'd',
          jsonLd: SeoJsonLd.raw({'x': '</script>'}),
        ),
      );
      expect(head, isNot(contains('</script></script>')));
      expect(head, contains(r'<\/script>'));
    });
  });
}
