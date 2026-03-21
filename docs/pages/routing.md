# Pages & Routing

Last verified: 2026-03-21

## Inject

Pages use Astro's file-based routing in `src/pages/`. All routes are relative to
the `/blog` base path.

Existing routes:
- `index.astro` — homepage with featured + recent posts
- `about.md` — about page (markdown with layout frontmatter)
- `search.astro` — Pagefind-powered search
- `posts/[...slug]/index.astro` — individual blog post pages
- `posts/[...page].astro` — paginated post listing
- `tags/index.astro` — all tags overview
- `tags/[tag]/[...page].astro` — posts filtered by tag (paginated)
- `archives/index.astro` — archive view
- `og.png.ts` — default site OG image endpoint
- `posts/[...slug]/index.png.ts` — per-post OG image endpoint
- `rss.xml.ts` — RSS feed
- `robots.txt.ts` — robots.txt

Dynamic routes use `getStaticPaths()` for static generation. When adding a new
static page, create it as `.astro` or `.md` in `src/pages/`.

Do not create API routes or server endpoints — this is a fully static site.

Canonical examples:
- Static page: `src/pages/about.md`
- Dynamic route: `src/pages/posts/[...slug]/index.astro`
- Paginated route: `src/pages/posts/[...page].astro`
