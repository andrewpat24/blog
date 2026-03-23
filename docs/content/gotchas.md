# Astro & AstroPaper Gotchas

Last verified: 2026-03-21

## Inject

Common traps that will waste your time if you hit them blind.

Date format in frontmatter must be ISO 8601: `2026-03-21T08:00:00Z`. Not `2026-03-21`,
not `March 21, 2026`, not `2026/03/21`. The Zod schema in `content.config.ts` validates
this at build time, but the error message isn't always obvious.

Images in `src/assets/` MUST use markdown syntax (`![alt](@/assets/...)`) for Astro
to optimize them. `<img>` tags bypass the optimization pipeline entirely. Images in
`public/` use absolute paths and are served as-is (no optimization).

The base path is `/blog`. If you hardcode any internal links, they need this prefix.
Astro's built-in routing handles this automatically for pages and components, but
markdown links to other posts need the full path: `[link text](/blog/posts/slug)`.

`getStaticPaths()` is required for all dynamic routes (`[...slug]`, `[...page]`).
If you forget it, the build succeeds locally but fails on GitHub Pages with a
cryptic error about missing paths.

New content schema fields MUST have `.optional()` with a default, or every existing
post without that field will fail validation at build time. Add the field to the
schema first, then start using it in new posts.

Code block transformers (diff, highlight) use comment syntax:
- `// [!code highlight]` -- highlights the line
- `// [!code ++]` / `// [!code --]` -- diff notation
- `file="filename.ts"` as a code fence attribute shows a filename header
These only work in fenced code blocks, not inline code.

Pagefind search index is built at `pnpm build` time. During `pnpm dev`, search
results may be stale or empty. This is expected.

## Reference

### Build failures on GitHub Pages

**"Cannot find module" errors after adding a new dependency**
GitHub Actions uses `pnpm install --frozen-lockfile`. If you added a dependency
but didn't commit the updated `pnpm-lock.yaml`, the build fails.

**"getStaticPaths() function is required" for dynamic routes**
Every `[param]` route needs this function to tell Astro which pages to generate
at build time. The error only shows during `pnpm build`, not `pnpm dev` (dev
uses on-demand rendering).

**OG image generation fails with font errors**
The OG image generator (`og.png.ts`) loads Google Fonts via HTTP at build time.
If the font URL changes or the network is unavailable, the build fails. The font
loading utility is in `src/utils/loadGoogleFont.ts`.

### Tailwind CSS 4 differences from v3
- `@apply` still works but is discouraged -- use utility classes directly
- Config is in `astro.config.ts` via Vite plugin, not `tailwind.config.js`
- Dark mode uses the `class` strategy (toggled by `data-theme` attribute)
- Custom colors are defined in CSS variables, not in a config file

### Markdown rendering quirks
- Astro's markdown renderer strips `<script>` and `<style>` tags from .md files
- HTML in markdown works but Astro components do NOT render in .md (use .mdx for that)
- Remark plugins (toc, collapse) run in the order specified in `astro.config.ts`
- The TOC plugin only works when you include `## Table of contents` as exact text
