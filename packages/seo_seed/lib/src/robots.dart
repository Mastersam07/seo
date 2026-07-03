/// Builds a robots.txt that allows all crawling and points crawlers at the
/// sitemap via an absolute [sitemapUrl].
///
/// `noindex` is deliberately not expressed as a `Disallow` here: a disallowed
/// page is never crawled, so its `<meta name="robots" content="noindex">` would
/// never be seen and the bare URL could still be indexed. Non-indexable routes
/// are instead omitted from the sitemap this file advertises (see
/// `SeoMetadata.indexable`), which keeps the two signals consistent.
///
/// robots.txt is only honored at the site root (`/robots.txt`); under subpath
/// hosting, place the generated file there rather than under the subpath.
String renderRobots(String sitemapUrl) =>
    'User-agent: *\n'
    'Allow: /\n'
    '\n'
    'Sitemap: $sitemapUrl\n';
