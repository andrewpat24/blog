# SEO & Discoverability

Last verified: 2026-03-21

## Inject

AstroPaper handles most SEO automatically, but these are the things it can't do for you.

Every post needs a unique, specific `description` in frontmatter. This becomes the meta
description in search results. Keep it under 155 characters. Don't stuff keywords --
write what someone would want to read before clicking.

OG images are auto-generated via Satori if you don't specify `ogImage` in frontmatter.
The default template is in `src/utils/og-templates/post.js`. If you want a custom OG
image for a post, add it to `src/assets/images/` and reference it:
```yaml
ogImage: ../../assets/images/my-post-og.png
```
OG image dimensions: 1200x640px. Social platforms crop differently -- keep important
content in the center 60% of the image.

`canonicalURL` in frontmatter is optional but important if you cross-post. Set it to
your blog URL so search engines know the original source:
```yaml
canonicalURL: https://andrewpatterson.dev/blog/posts/your-post-slug
```

The sitemap is auto-generated at `/blog/sitemap-index.xml` via `@astrojs/sitemap`.
The RSS feed is at `/blog/rss.xml`. Both are configured in `astro.config.ts` and
pull from `SITE.website`. If that value is wrong, all canonical URLs break.

Pagefind powers the search page. The search index is built at `pnpm build` time.
If search results are stale during dev, rebuild.

## Reference

### What AstroPaper generates automatically
- `<meta name="description">` from frontmatter `description`
- `<meta property="og:title">`, `og:description`, `og:image` from frontmatter
- `<link rel="canonical">` from `canonicalURL` or auto-generated
- `<link rel="sitemap">` pointing to sitemap-index.xml
- JSON-LD structured data (article schema) in `PostDetails.astro`
- `robots.txt` via `robots.txt.ts`

### Cross-posting with canonical URLs
When you cross-post to dev.to, Hashnode, or Medium:
1. Publish on your blog first (this establishes the canonical)
2. Wait for Google to index it (usually 1-3 days)
3. Cross-post with the canonical URL pointing back to your blog
4. dev.to has a "canonical URL" field in post settings
5. Hashnode has it in the article settings panel
6. Medium: add `rel="canonical"` to the import settings

### Submitting to Google Search Console
1. Verify your domain at https://search.google.com/search-console
2. Submit your sitemap: `https://andrewpatterson.dev/blog/sitemap-index.xml`
3. Use "URL Inspection" to request indexing for new posts
4. Monitor "Coverage" for crawl errors

### Submitting to Hacker News
- Title format: descriptive, no clickbait. HN penalizes "How I..." and "Why you should..."
- Better: "A three-tier convention enforcement system for AI coding agents"
- Post your first comment immediately with context (the Haiku data, the problem you solved)
- Best times: Tuesday-Thursday, 8-10am ET
- Don't ask for upvotes. Don't share the link with friends asking them to upvote. HN detects this.
