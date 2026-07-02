import 'dart:io';

import 'package:html/parser.dart' as html;
import 'package:seo_seed/seo_seed.dart';
import 'package:seo_seed/src/cache.dart';
import 'package:seo_seed/src/serialize.dart';
import 'package:seo_seed/src/head.dart';
import 'package:seo_seed/src/paths.dart';
import 'package:seo_seed/src/robots.dart';
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

    test('blockquote carries an optional cite', () {
      expect(
        serializeNode(b.blockquote('Quote')),
        '<blockquote>Quote</blockquote>',
      );
      expect(
        serializeNode(b.blockquote('Q', cite: 'https://x.dev')),
        '<blockquote cite="https://x.dev">Q</blockquote>',
      );
    });

    test('figure with figcaption', () {
      final node = b.figure([b.img('/a.png', alt: 'a'), b.figcaption('cap')]);
      expect(
        serializeNode(node),
        '<figure><img src="/a.png" alt="a"><figcaption>cap</figcaption></figure>',
      );
    });

    test('descriptionList emits dt/dd pairs in order', () {
      final node = b.descriptionList({'Term': 'Def', 'T2': 'D2'});
      expect(
        serializeNode(node),
        '<dl><dt>Term</dt><dd>Def</dd><dt>T2</dt><dd>D2</dd></dl>',
      );
    });

    test('dataTable builds a header row and body rows', () {
      final node = b.dataTable(
        headers: ['Plan', 'Price'],
        rows: [
          ['Free', '\$0'],
          ['Pro', '\$9'],
        ],
      );
      expect(
        serializeNode(node),
        '<table>'
        '<thead><tr><th>Plan</th><th>Price</th></tr></thead>'
        '<tbody>'
        '<tr><td>Free</td><td>\$0</td></tr>'
        '<tr><td>Pro</td><td>\$9</td></tr>'
        '</tbody>'
        '</table>',
      );
    });

    test('dataTable without headers omits thead', () {
      final node = b.dataTable(
        rows: [
          ['a', 'b'],
        ],
      );
      expect(
        serializeNode(node),
        '<table><tbody><tr><td>a</td><td>b</td></tr></tbody></table>',
      );
    });

    test('table cell content is escaped', () {
      final node = b.dataTable(
        rows: [
          ['<b>x</b>'],
        ],
      );
      expect(serializeNode(node), contains('<td>&lt;b&gt;x&lt;/b&gt;</td>'));
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

    test('inlines critical CSS as a marked style block, or omits it', () {
      final withCss = renderHead(
        const SeoMetadata(
          title: 't',
          description: 'd',
          criticalCss: '#seo-seed{font:16px sans-serif}',
        ),
      );
      expect(
        withCss,
        contains(
          '<style id="seo-seed-style">#seo-seed{font:16px sans-serif}</style>',
        ),
      );

      final withoutCss = renderHead(
        const SeoMetadata(title: 't', description: 'd'),
      );
      expect(withoutCss, isNot(contains('seo-seed-style')));
    });

    test('json-ld closing tags are neutralized', () {
      final head = renderHead(
        SeoMetadata(
          title: 't',
          description: 'd',
          jsonLd: [
            SeoJsonLd.raw({'x': '</script>'}),
          ],
        ),
      );
      // Only our own closing tag survives; the payload's `<` is \u-escaped.
      expect('</script>'.allMatches(head).length, 1);
      expect(head, contains('u003c'));
    });
  });

  group('JSON-LD schemas', () {
    test('organization emits name, url, logo and sameAs', () {
      final d = SeoJsonLd.organization(
        name: 'Sortd',
        url: 'https://sortd.app',
        logo: 'https://sortd.app/logo.png',
        sameAs: const ['https://twitter.com/sortd'],
      ).data;
      expect(d['@type'], 'Organization');
      expect(d['name'], 'Sortd');
      expect(d['logo'], 'https://sortd.app/logo.png');
      expect(d['sameAs'], ['https://twitter.com/sortd']);
    });

    test('organization omits empty optional fields', () {
      final d = SeoJsonLd.organization(name: 'x', url: 'https://x.dev').data;
      expect(d.containsKey('sameAs'), isFalse);
      expect(d.containsKey('logo'), isFalse);
    });

    test('product with a price includes a well-formed Offer', () {
      final d = SeoJsonLd.product(
        name: 'Pro',
        brand: 'Sortd',
        price: '9.99',
        priceCurrency: 'USD',
        availability: 'https://schema.org/InStock',
      ).data;
      expect(d['@type'], 'Product');
      expect((d['brand'] as Map<String, dynamic>)['@type'], 'Brand');
      final offer = d['offers'] as Map<String, dynamic>;
      expect(offer['@type'], 'Offer');
      expect(offer['price'], '9.99');
      expect(offer['priceCurrency'], 'USD');
      expect(offer['availability'], 'https://schema.org/InStock');
    });

    test('product without a price has no Offer', () {
      expect(SeoJsonLd.product(name: 'Free').data.containsKey('offers'), false);
    });

    test('faq nests questions and accepted answers', () {
      final d = SeoJsonLd.faq(const [
        (question: 'Is it free?', answer: 'Yes for personal use.'),
      ]).data;
      expect(d['@type'], 'FAQPage');
      final q =
          (d['mainEntity'] as List<dynamic>).first as Map<String, dynamic>;
      expect(q['@type'], 'Question');
      expect(q['name'], 'Is it free?');
      expect(
        (q['acceptedAnswer'] as Map<String, dynamic>)['text'],
        'Yes for personal use.',
      );
    });

    test('breadcrumbTrail builds absolute items from a path', () {
      final d = SeoJsonLd.breadcrumbTrail(
        path: '/post/splitting-rent-fairly',
        base: 'https://x.dev',
      ).data;
      expect(d['@type'], 'BreadcrumbList');
      final items = (d['itemListElement'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(items.map((i) => i['name']), [
        'Home',
        'Post',
        'Splitting Rent Fairly',
      ]);
      expect(items.map((i) => i['item']), [
        'https://x.dev',
        'https://x.dev/post',
        'https://x.dev/post/splitting-rent-fairly',
      ]);
    });

    test('breadcrumbTrail honors name overrides and is relative sans base', () {
      final d = SeoJsonLd.breadcrumbTrail(
        path: '/post/x',
        names: const {'post': 'Blog'},
      ).data;
      final items = (d['itemListElement'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(items[1]['name'], 'Blog');
      expect(items[1]['item'], '/post');
    });

    test('renderHead emits one script per block', () {
      final head = renderHead(
        SeoMetadata(
          title: 't',
          description: 'd',
          jsonLd: [
            SeoJsonLd.article(headline: 'h'),
            SeoJsonLd.faq(const [(question: 'q', answer: 'a')]),
          ],
        ),
      );
      expect('application/ld+json'.allMatches(head).length, 2);
      expect(head, contains('"@type":"Article"'));
      expect(head, contains('"@type":"FAQPage"'));
    });

    test('every factory declares the schema.org context and a type', () {
      final blocks = [
        SeoJsonLd.article(headline: 'h'),
        SeoJsonLd.website(name: 'n', url: 'https://x.dev'),
        SeoJsonLd.breadcrumb(const [(name: 'Home', url: 'https://x.dev')]),
        SeoJsonLd.organization(name: 'n', url: 'https://x.dev'),
        SeoJsonLd.product(name: 'p'),
        SeoJsonLd.faq(const [(question: 'q', answer: 'a')]),
      ];
      for (final block in blocks) {
        expect(block.data['@context'], 'https://schema.org');
        expect(block.data['@type'], isA<String>());
      }
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
            jsonLd: [
              SeoJsonLd.raw({'x': payload}),
            ],
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

    test('sitemap formats each loc into a url entry', () {
      final xml = renderSitemap([
        (
          loc: 'https://x.dev/pricing',
          lastmod: null,
          changeFreq: null,
          priority: null,
          images: const <String>[],
          alternates: const <String, String>{},
        ),
      ]);
      expect(xml, contains('<loc>https://x.dev/pricing</loc>'));
      expect(xml, contains('<urlset'));
    });

    test('sitemap emits lastmod, changefreq, priority and images', () {
      final xml = renderSitemap([
        (
          loc: 'https://x.dev/post/hi',
          lastmod: DateTime.utc(2026, 1, 5),
          changeFreq: SeoChangeFreq.weekly,
          priority: 0.8,
          images: const ['https://x.dev/og/hi.png'],
          alternates: const <String, String>{},
        ),
      ]);
      expect(xml, contains('<lastmod>2026-01-05</lastmod>'));
      expect(xml, contains('<changefreq>weekly</changefreq>'));
      expect(xml, contains('<priority>0.8</priority>'));
      expect(xml, contains('<image:loc>https://x.dev/og/hi.png</image:loc>'));
      expect(xml, contains('xmlns:image='));
    });

    test('sitemap clamps priority into range', () {
      final xml = renderSitemap([
        (
          loc: 'https://x.dev/a',
          lastmod: null,
          changeFreq: null,
          priority: 5.0,
          images: const <String>[],
          alternates: const <String, String>{},
        ),
      ]);
      expect(xml, contains('<priority>1.0</priority>'));
    });
  });

  group('canonical URL resolution', () {
    test('resolveUrl joins a relative path onto the site base', () {
      expect(resolveUrl('/pricing', 'https://x.dev'), 'https://x.dev/pricing');
      expect(
        resolveUrl('/pricing', 'https://x.dev/app'),
        'https://x.dev/app/pricing',
      );
      expect(resolveUrl('og/a.png', 'https://x.dev'), 'https://x.dev/og/a.png');
    });

    test('resolveUrl leaves absolute and protocol-relative URLs alone', () {
      expect(
        resolveUrl('https://cdn.dev/a.png', 'https://x.dev'),
        'https://cdn.dev/a.png',
      );
      expect(resolveUrl('//cdn.dev/a.png', 'https://x.dev'), '//cdn.dev/a.png');
    });

    test('resolveUrl with no site base returns the input unchanged', () {
      expect(resolveUrl('/pricing', null), '/pricing');
    });

    test('renderHead makes canonical, og:url and images absolute', () {
      final head = renderHead(
        const SeoMetadata(
          title: 't',
          description: 'd',
          canonical: '/post/hi/',
          openGraph: OpenGraph(image: '/og/hi.png'),
          twitter: TwitterCard(),
        ),
        siteBase: 'https://x.dev/app',
      );
      expect(
        head,
        contains('rel="canonical" href="https://x.dev/app/post/hi"'),
      );
      expect(
        head,
        contains('property="og:url" content="https://x.dev/app/post/hi"'),
      );
      expect(
        head,
        contains('property="og:image" content="https://x.dev/app/og/hi.png"'),
      );
      expect(
        head,
        contains('name="twitter:image" content="https://x.dev/app/og/hi.png"'),
      );
    });

    test('renderHead without a site base keeps URLs relative', () {
      final head = renderHead(
        const SeoMetadata(title: 't', description: 'd', canonical: '/post/hi'),
      );
      expect(head, contains('rel="canonical" href="/post/hi"'));
    });
  });

  group('robots.txt and noindex', () {
    test('indexable reflects the robots directive', () {
      SeoMetadata meta(String? robots) =>
          SeoMetadata(title: 't', description: 'd', robots: robots);
      expect(meta(null).indexable, isTrue);
      expect(meta('index, follow').indexable, isTrue);
      expect(meta('noindex').indexable, isFalse);
      expect(meta('noindex, follow').indexable, isFalse);
      expect(meta('none').indexable, isFalse);
    });

    test('renderRobots allows all and points at the sitemap', () {
      final txt = renderRobots('https://x.dev/sitemap.xml');
      expect(txt, contains('User-agent: *'));
      expect(txt, contains('Allow: /'));
      expect(txt, contains('Sitemap: https://x.dev/sitemap.xml'));
      expect(txt, isNot(contains('Disallow')));
    });
  });

  group('locale strategies', () {
    test('PathPrefixLocales prefixes path and URL', () {
      const s = PathPrefixLocales();
      expect(s.pathFor('fr', '/pricing'), '/fr/pricing');
      expect(
        s.urlFor('fr', '/pricing', 'https://x.dev'),
        'https://x.dev/fr/pricing',
      );
    });

    test('SubdomainLocales puts the locale in the host', () {
      const s = SubdomainLocales(domain: 'example.com');
      expect(s.pathFor('fr', '/pricing'), '/fr/pricing');
      expect(
        s.urlFor('fr', '/pricing', 'https://example.com'),
        'https://fr.example.com/pricing',
      );
    });

    test('DomainLocales maps each locale to its origin', () {
      const s = DomainLocales({
        'en': 'https://example.com',
        'fr': 'https://example.fr',
      });
      expect(
        s.urlFor('fr', '/pricing', 'https://example.com'),
        'https://example.fr/pricing',
      );
      expect(
        () => s.urlFor('de', '/pricing', 'https://example.com'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('sitemap sharding', () {
    SitemapEntry loc(String l) => (
      loc: l,
      lastmod: null,
      changeFreq: null,
      priority: null,
      images: const <String>[],
      alternates: const <String, String>{},
    );

    test('single sitemap.xml under the shard limit', () {
      final files = <String, String>{};
      SitemapShardWriter(
          siteBase: 'https://x.dev',
          write: (n, c) => files[n] = c,
          limit: 5,
        )
        ..add(loc('https://x.dev/a'))
        ..finish();
      expect(files.keys, ['sitemap.xml']);
      expect(files['sitemap.xml'], contains('<urlset'));
      expect(files['sitemap.xml'], contains('https://x.dev/a'));
    });

    test('shards and writes an index past the limit', () {
      final files = <String, String>{};
      final w = SitemapShardWriter(
        siteBase: 'https://x.dev',
        write: (n, c) => files[n] = c,
        limit: 2,
      );
      for (var i = 1; i <= 5; i++) {
        w.add(loc('https://x.dev/p$i'));
      }
      w.finish();

      expect(
        files.keys,
        containsAll([
          'sitemap-1.xml',
          'sitemap-2.xml',
          'sitemap-3.xml',
          'sitemap.xml',
        ]),
      );
      expect(files['sitemap.xml'], contains('<sitemapindex'));
      expect(
        files['sitemap.xml'],
        contains('<loc>https://x.dev/sitemap-1.xml</loc>'),
      );
      expect(files['sitemap-1.xml'], contains('<urlset'));
    });
  });

  group('incremental cache', () {
    test('contentHash is stable and change-sensitive', () {
      expect(contentHash('abc'), contentHash('abc'));
      expect(contentHash('abc'), isNot(contentHash('abd')));
    });

    test('round-trips version, hash and sitemap entry', () {
      final dir = Directory.systemTemp.createTempSync('seo_cache');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/c.json');

      SeoBuildCache.load(file, 'key1')
        ..record('/p', version: 'v1', hash: 'h1', sitemap: {'loc': 'x'})
        ..save(file);

      final reloaded = SeoBuildCache.load(file, 'key1');
      expect(reloaded.unchangedByVersion('/p', 'v1'), isTrue);
      expect(reloaded.unchangedByVersion('/p', 'v2'), isFalse);
      expect(reloaded.unchangedByHash('/p', 'h1'), isTrue);
      expect(reloaded.sitemapFor('/p'), {'loc': 'x'});
    });

    test('a changed buildKey discards the previous manifest', () {
      final dir = Directory.systemTemp.createTempSync('seo_cache');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/c.json');
      SeoBuildCache.load(file, 'key1')
        ..record('/p', version: 'v1', hash: 'h1')
        ..save(file);

      expect(
        SeoBuildCache.load(file, 'key2').unchangedByVersion('/p', 'v1'),
        isFalse,
      );
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

    test('page canonical is absolute and matches the sitemap', () async {
      final dir = tempWithShell(
        '<!DOCTYPE html><html><head><base href="/app/"></head>'
        '<body></body></html>',
      );
      final route = SeoRoute.static(
        path: '/pricing',
        metadata: () => const SeoMetadata(
          title: 't',
          description: 'd',
          canonical: '/pricing',
        ),
        content: (b) => b.h1('x'),
      );
      await SeoBuilder([
        route,
      ]).run(['--output', dir.path, '--base-url', 'https://example.com']);

      final page = File('${dir.path}/pricing/index.html').readAsStringSync();
      final sitemap = File('${dir.path}/sitemap.xml').readAsStringSync();
      expect(
        page,
        contains('rel="canonical" href="https://example.com/app/pricing"'),
      );
      expect(sitemap, contains('https://example.com/app/pricing'));
    });

    test(
      'writes robots.txt and omits noindex pages from the sitemap',
      () async {
        final dir = tempWithShell(
          '<!DOCTYPE html><html><head><base href="/"></head>'
          '<body></body></html>',
        );
        final secret = SeoRoute.static(
          path: '/secret',
          metadata: () => const SeoMetadata(
            title: 'Secret',
            description: 'd',
            robots: 'noindex, follow',
          ),
          content: (b) => b.h1('secret'),
        );
        await SeoBuilder([
          pricing(),
          secret,
        ]).run(['--output', dir.path, '--base-url', 'https://example.com']);

        // The noindex page is still generated (so crawlers see the meta)...
        final page = File('${dir.path}/secret/index.html').readAsStringSync();
        expect(page, contains('name="robots" content="noindex, follow"'));

        // ...but is kept out of the sitemap, while the indexable page stays.
        final sitemap = File('${dir.path}/sitemap.xml').readAsStringSync();
        expect(sitemap, contains('https://example.com/pricing'));
        expect(sitemap, isNot(contains('/secret')));

        final robots = File('${dir.path}/robots.txt').readAsStringSync();
        expect(robots, contains('Sitemap: https://example.com/sitemap.xml'));
      },
    );

    test('sitemap carries hints with images resolved to absolute', () async {
      final dir = tempWithShell(
        '<!DOCTYPE html><html><head><base href="/"></head>'
        '<body></body></html>',
      );
      final route = SeoRoute.static(
        path: '/pricing',
        metadata: () => SeoMetadata(
          title: 't',
          description: 'd',
          sitemap: SeoSitemap(
            lastmod: DateTime.utc(2026, 2, 3),
            changeFreq: SeoChangeFreq.monthly,
            priority: 0.9,
            images: const ['/og/pricing.png'],
          ),
        ),
        content: (b) => b.h1('x'),
      );
      await SeoBuilder([
        route,
      ]).run(['--output', dir.path, '--base-url', 'https://example.com']);

      final sitemap = File('${dir.path}/sitemap.xml').readAsStringSync();
      expect(sitemap, contains('<lastmod>2026-02-03</lastmod>'));
      expect(sitemap, contains('<changefreq>monthly</changefreq>'));
      expect(sitemap, contains('<priority>0.9</priority>'));
      expect(
        sitemap,
        contains('<image:loc>https://example.com/og/pricing.png</image:loc>'),
      );
    });

    test(
      'breadcrumbs:true appends a BreadcrumbList from the route path',
      () async {
        final dir = tempWithShell(
          '<!DOCTYPE html><html><head><base href="/"></head>'
          '<body></body></html>',
        );
        final route = SeoRoute.dynamic(
          path: '/post/[slug]',
          params: () async => [
            const SeoParams({'slug': 'hi-there'}),
          ],
          metadata: (_) => const SeoMetadata(
            title: 't',
            description: 'd',
            breadcrumbs: true,
          ),
          content: (_, b) => b.h1('x'),
        );
        await SeoBuilder([
          route,
        ]).run(['--output', dir.path, '--base-url', 'https://example.com']);

        final page = File(
          '${dir.path}/post/hi-there/index.html',
        ).readAsStringSync();
        expect(page, contains('BreadcrumbList'));
        expect(page, contains('https://example.com/post/hi-there'));
        expect(page, contains('Hi There')); // humanized leaf segment
      },
    );

    test('localized route generates per-locale pages with hreflang', () async {
      final dir = tempWithShell(
        '<!DOCTYPE html><html><head><base href="/"></head>'
        '<body></body></html>',
      );
      final route = SeoRoute.dynamic(
        path: '/pricing',
        locales: const ['en', 'fr'],
        params: () async => const [SeoParams.empty],
        metadata: (p) => SeoMetadata(
          title: p.locale == 'fr' ? 'Tarifs' : 'Pricing',
          description: 'd',
        ),
        content: (p, b) => b.h1(p.locale == 'fr' ? 'Tarifs' : 'Pricing'),
      );
      await SeoBuilder(
        [route],
        defaultLocale: 'en',
      ).run(['--output', dir.path, '--base-url', 'https://example.com']);

      final en = File('${dir.path}/en/pricing/index.html').readAsStringSync();
      final fr = File('${dir.path}/fr/pricing/index.html').readAsStringSync();

      // Translated content per locale.
      expect(en, contains('<title>Pricing</title>'));
      expect(fr, contains('<title>Tarifs</title>'));

      // Each page self-canonicalizes and carries reciprocal hreflang + x-default.
      expect(
        en,
        contains('rel="canonical" href="https://example.com/en/pricing"'),
      );
      for (final page in [en, fr]) {
        expect(
          page,
          contains(
            '<link rel="alternate" hreflang="en" '
            'href="https://example.com/en/pricing">',
          ),
        );
        expect(
          page,
          contains(
            '<link rel="alternate" hreflang="fr" '
            'href="https://example.com/fr/pricing">',
          ),
        );
        expect(
          page,
          contains(
            '<link rel="alternate" hreflang="x-default" '
            'href="https://example.com/en/pricing">',
          ),
        );
      }

      // Sitemap lists both locales with xhtml:link alternates.
      final sitemap = File('${dir.path}/sitemap.xml').readAsStringSync();
      expect(sitemap, contains('<loc>https://example.com/en/pricing</loc>'));
      expect(sitemap, contains('<loc>https://example.com/fr/pricing</loc>'));
      expect(
        sitemap,
        contains(
          '<xhtml:link rel="alternate" hreflang="fr" '
          'href="https://example.com/fr/pricing"/>',
        ),
      );
    });

    test('incremental skips unchanged pages but keeps the sitemap', () async {
      final dir = tempWithShell(
        '<!DOCTYPE html><html><head><base href="/"></head>'
        '<body></body></html>',
      );
      SeoRoute post(String version) => SeoRoute.dynamic(
        path: '/post/[slug]',
        params: () async => [
          SeoParams(const {'slug': 'hi'}, version: version),
        ],
        metadata: (_) => const SeoMetadata(title: 'Hi', description: 'd'),
        content: (_, b) => b.h1('hi'),
      );
      final args = [
        '--output',
        dir.path,
        '--base-url',
        'https://x.dev',
        '--incremental',
      ];

      final first = await SeoBuilder([post('v1')]).run(args);
      expect(first.pageCount, 1);
      expect(first.skipped, 0);

      final second = await SeoBuilder([post('v1')]).run(args);
      expect(second.pageCount, 0);
      expect(second.skipped, 1);
      // The skipped page still appears in the sitemap (replayed from cache).
      expect(
        File('${dir.path}/sitemap.xml').readAsStringSync(),
        contains('https://x.dev/post/hi'),
      );

      final third = await SeoBuilder([post('v2')]).run(args);
      expect(third.pageCount, 1);
      expect(third.skipped, 0);
    });

    test('paramsStream generates a page per yielded param', () async {
      final dir = tempWithShell(
        '<!DOCTYPE html><html><head><base href="/"></head>'
        '<body></body></html>',
      );
      final route = SeoRoute.dynamic(
        path: '/p/[id]',
        paramsStream: () async* {
          for (final id in ['a', 'b', 'c']) {
            yield SeoParams({'id': id});
          }
        },
        metadata: (_) => const SeoMetadata(title: 't', description: 'd'),
        content: (_, b) => b.h1('x'),
      );
      final result = await SeoBuilder([route]).run(['--output', dir.path]);
      expect(result.pageCount, 3);
      expect(File('${dir.path}/p/a/index.html').existsSync(), isTrue);
      expect(File('${dir.path}/p/c/index.html').existsSync(), isTrue);
    });

    test('dynamic route needs exactly one of params/paramsStream', () {
      md() => const SeoMetadata(title: 't', description: 'd');
      expect(
        () => SeoRoute.dynamic(
          path: '/p',
          metadata: (_) => md(),
          content: (_, b) => b.p('x'),
        ),
        throwsArgumentError,
      );
      expect(
        () => SeoRoute.dynamic(
          path: '/p',
          params: () async => const [],
          paramsStream: () async* {},
          metadata: (_) => md(),
          content: (_, b) => b.p('x'),
        ),
        throwsArgumentError,
      );
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
