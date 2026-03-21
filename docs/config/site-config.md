# Site Configuration

Last verified: 2026-03-21

## Inject

Site metadata lives in `src/config.ts` as the `SITE` constant. This is the single source
of truth for site-wide settings: title, author, description, OG image, locale, etc.

The site deploys to GitHub Pages with base path `/blog`. This is set in `astro.config.ts`:
```ts
base: "/blog",
```
All internal links must account for this base path. Astro handles it automatically
for pages and assets, but hardcoded paths need the prefix.

`astro.config.ts` key settings:
- `site`: from `SITE.website` — used for canonical URLs, sitemap, RSS
- `base`: `/blog` — GitHub Pages subpath
- Markdown: remark-toc + remark-collapse for TOC generation
- Shiki: `min-light` / `night-owl` themes with diff/highlight transformers
- Tailwind CSS 4 via Vite plugin

When changing site metadata, edit `src/config.ts` only. Do not scatter config values
across multiple files.

Canonical examples:
- SITE constant: `src/config.ts:1-23`
- Astro config: `astro.config.ts:15-74`
