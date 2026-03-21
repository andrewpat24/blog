# Utilities

Last verified: 2026-03-21

## Inject

Utility functions live in `src/utils/`. Use named exports only — no `export default`.

Existing utilities to reuse (don't recreate):
- `getSortedPosts.ts` — returns posts sorted by date (newest first)
- `getPostsByTag.ts` — filter posts by tag
- `getUniqueTags.ts` — deduplicated tag list from all posts
- `postFilter.ts` — filters out drafts and future-dated posts
- `slugify.ts` — consistent slug generation
- `getPath.ts` — path utilities
- `getPostsByGroupCondition.ts` — group posts by arbitrary condition
- `generateOgImages.ts` — Satori-based OG image generation
- `loadGoogleFont.ts` — font loading for OG images

OG image templates are in `src/utils/og-templates/` — `site.js` for the default
site OG, `post.js` for per-post OG images. These return Satori markup (JSX-like objects).

Canonical examples:
- Named exports: `src/utils/getSortedPosts.ts`
- OG template: `src/utils/og-templates/post.js`
