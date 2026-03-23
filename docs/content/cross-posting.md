# Cross-Posting & Distribution

Last verified: 2026-03-21

## Inject

Your blog is the canonical source. Everything else points back to it.
Do not publish on other platforms before publishing here. The canonical URL
must be established on your domain first.

When adapting a post for another platform, keep the content identical but adjust
formatting for the platform's renderer. Notion markdown, dev.to markdown, and
Astro markdown all handle code blocks and tables slightly differently.

## Reference

### Platform-specific formatting notes

**dev.to**
- Supports markdown natively, mostly compatible with Astro markdown
- Code blocks with language tags work: ````typescript`, ````bash`, etc.
- Tables render fine
- Set canonical URL in post settings (not in the article body)
- Tags: max 4, lowercase, no spaces (use hyphens)
- Cover image: 1000x420px recommended
- Series feature: group related posts (convention enforcement + 80 integrations + middleware)

**Hashnode**
- Full markdown support including tables and code blocks
- Canonical URL in article settings
- Tags are free-form
- Supports custom OG images
- "Back up to GitHub" feature can sync but don't use it as primary -- your Astro repo is primary

**LinkedIn Articles**
- Markdown not supported -- paste as rich text
- Code blocks render poorly. Use screenshots for code or keep code minimal.
- No canonical URL support -- add a "Originally published at [link]" at the top
- Good for the non-technical framing (80 integrations article). Less good for the enforcement article.

**Medium**
- Import from URL: Medium can import and set canonical automatically
- Code blocks are mediocre -- no syntax highlighting for most languages
- Gists embed well if you need highlighted code
- Publications (Towards AI, Better Programming, etc.) give more reach than personal Medium

**Hacker News**
- Not a cross-post -- just a link submission with your blog URL
- Title is everything. Keep it factual, not promotional.
- First comment should add context the title can't convey
- Don't link to the same domain more than once a week

### Publishing order for a new article
1. Publish to andrewpatterson.dev (commit + push to main)
2. Wait for GitHub Pages deploy (~2 min)
3. Verify the post renders correctly and OG image works (check with https://opengraph.xyz)
4. Submit to Google Search Console for indexing
5. Post to Hacker News if it's a strong technical piece
6. Cross-post to dev.to with canonical URL (same day or next day)
7. Share on LinkedIn with a short personal take (not just the link)
8. Cross-post to Hashnode if relevant
