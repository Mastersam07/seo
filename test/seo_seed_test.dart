import 'dart:io';

import 'package:html/parser.dart' as html;
import 'package:seo_seed/seo_seed.dart';
import 'package:seo_seed/src/serialize.dart';
import 'package:seo_seed/src/head.dart';
import 'package:seo_seed/src/paths.dart';
import 'package:seo_seed/src/sitemap.dart';
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

    test('fails loudly naming the route and the missing segment', () {
      final route = SeoRoute.dynamic(
        path: '/post/[id]',
        params: () async => const [],
        metadata: (_) => const SeoMetadata(title: 't', description: 'd'),
        content: (_, b) => b.p('x'),
      );
      expect(
        () => route.resolvePath(const SeoParams({'slug': 'x'})),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('/post/[id]'), contains("'id'")),
          ),
        ),
      );
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
      // Only our own closing tag survives; the payload's `<` is \u-escaped.
      expect('</script>'.allMatches(head).length, 1);
      expect(head, contains('u003c'));
    });
  });

  group('injectPage', () {
    const shell = '''
<!DOCTYPE html>
<html>
<head>
  <base href="/">
  <meta charset="UTF-8">
  <title>flutter_app</title>
  <meta name="description" content="A new Flutter project.">
</head>
<body>
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>''';

    String inject(String head, {String seed = '', String baseHref = '/'}) =>
        injectPage(shell, head: head, seed: seed, baseHref: baseHref);

    test('replaces the shell title instead of duplicating it', () {
      final out = inject('<title>Pricing - Sortd</title>');
      expect('<title>'.allMatches(out).length, 1);
      expect(out, contains('<title>Pricing - Sortd</title>'));
      expect(out, isNot(contains('flutter_app')));
    });

    test('replaces a meta of the same name', () {
      final out = inject(
        '<meta name="description" content="Real description">',
      );
      expect(RegExp('<meta name="description"').allMatches(out).length, 1);
      expect(out, contains('Real description'));
      expect(out, isNot(contains('A new Flutter project.')));
    });

    test('leaves unrelated shell tags in place', () {
      final out = inject('<title>x</title>');
      expect(out, contains('charset="UTF-8"'));
      expect(out, contains('src="flutter_bootstrap.js"'));
    });

    test('forces the base href and keeps a single base tag', () {
      final out = inject('<title>x</title>', baseHref: '/app/');
      expect('<base '.allMatches(out).length, 1);
      expect(out, contains('<base href="/app/">'));
    });

    test('inserts a base tag when the shell has none', () {
      const bare = '<!DOCTYPE html><html><head></head><body></body></html>';
      final out = injectPage(bare, head: '', seed: '', baseHref: '/');
      expect(out, contains('<base href="/">'));
    });

    test('prepends the seed block as the first body child', () {
      final out = inject('<title>x</title>', seed: '<h1>Hi</h1>');
      expect(out, contains('<div id="seo-seed"><h1>Hi</h1></div>'));
      final seedAt = out.indexOf('id="seo-seed"');
      final bootAt = out.indexOf('flutter_bootstrap.js');
      expect(seedAt, lessThan(bootAt));
    });

    test('preserves the doctype', () {
      final out = inject('<title>x</title>');
      expect(out.trimLeft(), startsWith('<!DOCTYPE html>'));
    });

    test('lenient parsing still yields a full document from loose input', () {
      final out = injectPage(
        '<p>not a document</p>',
        head: '<title>t</title>',
        seed: '<h1>Hi</h1>',
        baseHref: '/',
      );
      expect(out, contains('<title>t</title>'));
      expect(out, contains('<div id="seo-seed"><h1>Hi</h1></div>'));
    });
  });

  group('escaping (hostile input)', () {
    test('escapeHtml neutralizes tag injection and keeps unicode', () {
      expect(
        escapeHtml('<script>alert(1)</script>'),
        '&lt;script&gt;alert(1)&lt;/script&gt;',
      );
      expect(escapeHtml('a & <b>'), 'a &amp; &lt;b&gt;');
      expect(escapeHtml('café ☕ 日本 𝕏'), 'café ☕ 日本 𝕏');
    });

    test('escapeAttr neutralizes quote breakout', () {
      expect(escapeAttr('" onmouseover="x'), '&quot; onmouseover=&quot;x');
      expect(escapeAttr("' onload='x"), '&#39; onload=&#39;x');
    });

    test('hostile content through the builder is inert', () {
      expect(
        serializeNode(b.p('</p><script>alert(1)</script>')),
        '<p>&lt;/p&gt;&lt;script&gt;alert(1)&lt;/script&gt;</p>',
      );
      expect(
        serializeNode(b.a('/x" onclick="evil()', 'go')),
        '<a href="/x&quot; onclick=&quot;evil()">go</a>',
      );
    });

    test('json-ld payload cannot break out of or mis-nest the script', () {
      for (final payload in const [
        '<!--<script>',
        '</script><script>alert(1)</script>',
        '"><img src=x onerror=alert(1)>',
      ]) {
        final head = renderHead(
          SeoMetadata(
            title: 't',
            description: 'd',
            jsonLd: SeoJsonLd.raw({'x': payload}),
          ),
        );
        // Re-parse as a browser would; the sentinel body must survive whole.
        final page = html.parse(
          '<html><head>$head</head><body><h1>SENTINEL</h1></body></html>',
        );
        expect(page.querySelectorAll('script').length, 1, reason: payload);
        expect(
          page.body?.querySelector('h1')?.text,
          'SENTINEL',
          reason: payload,
        );
      }
    });

    test('hostile attribute names cannot inject markup', () {
      // extraMeta key in the head, and a raw attribute key in the seed.
      final head = renderHead(
        const SeoMetadata(
          title: 't',
          description: 'd',
          extraMeta: {'x"><script>alert(1)</script>': 'v'},
        ),
      );
      final seed = serializeNode(
        const SeoElement('div', attributes: {'y"><script>bad</script>': 'v'}),
      );
      const shell = '<!DOCTYPE html><html><head></head><body></body></html>';
      final page = html.parse(
        injectPage(shell, head: head, seed: seed, baseHref: '/'),
      );
      expect(page.querySelectorAll('script'), isEmpty);
    });

    test('hostile seed survives injectPage as escaped text', () {
      const shell =
          '<!DOCTYPE html><html><head></head>'
          '<body><h1>REAL</h1></body></html>';
      final out = injectPage(
        shell,
        head: '',
        seed: serializeNode(b.p('<script>alert(1)</script>')),
        baseHref: '/',
      );
      expect(out, contains('REAL'));
      expect(out, isNot(contains('<script>alert(1)')));
      expect(out, contains('&lt;script&gt;alert(1)'));
    });
  });

  group('trailing-slash policy', () {
    test('canonicalizeUrl strips trailing slash except root', () {
      expect(canonicalizeUrl('/post/abc/'), '/post/abc');
      expect(canonicalizeUrl('/post/abc'), '/post/abc');
      expect(canonicalizeUrl('/'), '/');
      expect(canonicalizeUrl(''), '/');
      expect(canonicalizeUrl('/pricing///'), '/pricing');
    });

    test('canonicalizeUrl preserves scheme on absolute URLs', () {
      expect(
        canonicalizeUrl('https://x.dev/post/abc/'),
        'https://x.dev/post/abc',
      );
      expect(canonicalizeUrl('https://x.dev/'), 'https://x.dev');
    });

    test('resolvePath drops a trailing slash from the route path', () {
      final route = SeoRoute.static(
        path: '/pricing/',
        metadata: () => const SeoMetadata(title: 't', description: 'd'),
        content: (b) => b.p('x'),
      );
      expect(route.resolvePath(SeoParams.empty), '/pricing');
    });

    test('canonical tag is normalized', () {
      final head = renderHead(
        const SeoMetadata(title: 't', description: 'd', canonical: '/hello/'),
      );
      expect(head, contains('rel="canonical" href="/hello"'));
      expect(head, isNot(contains('/hello/"')));
    });

    test('sitemap loc has no trailing slash', () async {
      final route = SeoRoute.static(
        path: '/pricing/',
        metadata: () => const SeoMetadata(title: 't', description: 'd'),
        content: (b) => b.p('x'),
      );
      final xml = await renderSitemap([route], 'https://x.dev/');
      expect(xml, contains('<loc>https://x.dev/pricing</loc>'));
    });
  });

  group('SeoBuilder.run', () {
    SeoRoute pricing() => SeoRoute.static(
      path: '/pricing',
      metadata: () => const SeoMetadata(title: 'Pricing', description: 'd'),
      content: (b) => b.h1('Pricing'),
    );

    Directory tempWithShell(String shell) {
      final dir = Directory.systemTemp.createTempSync('seo_seed_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/index.html').writeAsStringSync(shell);
      return dir;
    }

    test('inherits the shell base href when --base-href is omitted', () async {
      final dir = tempWithShell(
        '<!DOCTYPE html><html><head><base href="/app/">'
        '<title>shell</title></head><body></body></html>',
      );
      await SeoBuilder([
        pricing(),
      ]).run(['--output', dir.path, '--base-url', 'https://example.com']);

      final page = File('${dir.path}/pricing/index.html').readAsStringSync();
      expect(page, contains('<base href="/app/">'));
      expect(page, contains('<title>Pricing</title>'));

      final sitemap = File('${dir.path}/sitemap.xml').readAsStringSync();
      expect(sitemap, contains('https://example.com/app/pricing'));
    });

    test('root base href produces unprefixed sitemap URLs', () async {
      final dir = tempWithShell(
        '<!DOCTYPE html><html><head><base href="/"></head>'
        '<body></body></html>',
      );
      await SeoBuilder([
        pricing(),
      ]).run(['--output', dir.path, '--base-url', 'https://example.com']);

      final sitemap = File('${dir.path}/sitemap.xml').readAsStringSync();
      expect(sitemap, contains('<loc>https://example.com/pricing</loc>'));
    });

    test('collects a failing route but keeps generating the others', () async {
      final saved = exitCode;
      try {
        final dir = tempWithShell(
          '<!DOCTYPE html><html><head></head><body></body></html>',
        );
        final bad = SeoRoute.dynamic(
          path: '/post/[id]',
          params: () async => [
            const SeoParams({'wrong': 'x'}),
          ],
          metadata: (_) => const SeoMetadata(title: 't', description: 'd'),
          content: (_, b) => b.p('x'),
        );

        final result = await SeoBuilder([
          pricing(),
          bad,
        ]).run(['--output', dir.path]);

        expect(result.ok, isFalse);
        expect(result.pageCount, 1); // the good route still generated
        expect(result.failures, hasLength(1));
        expect(result.failures.single.route, '/post/[id]');
        expect(result.failures.single.params, {'wrong': 'x'});
        expect(result.failures.single.message, contains("'id'"));
        expect(result.toJson()['ok'], isFalse);
        expect(exitCode, isNot(0));
        expect(File('${dir.path}/pricing/index.html').existsSync(), isTrue);
      } finally {
        exitCode = saved;
      }
    });

    test('missing shell reports a failure and exits non-zero', () async {
      final saved = exitCode;
      try {
        final dir = Directory.systemTemp.createTempSync('seo_seed_test');
        addTearDown(() => dir.deleteSync(recursive: true));

        final result = await SeoBuilder([
          pricing(),
        ]).run(['--output', dir.path]);

        expect(result.ok, isFalse);
        expect(result.failures.single.route, '(shell)');
        expect(exitCode, 2);
      } finally {
        exitCode = saved;
      }
    });
  });
}
