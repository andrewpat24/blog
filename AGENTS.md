# AGENTS.md — Blog Convention Guide (Hot Memory)

## Stack

Astro Paper v5 blog. Astro 5 + Tailwind CSS 4 + TypeScript. Deployed to GitHub Pages at `/blog` base path.

## Directory Map

```
src/
  config.ts              # Site-wide config (SITE constant)
  constants.ts           # App constants
  content.config.ts      # Astro content collection schema
  env.d.ts               # TypeScript env declarations
  data/
    blog/                # Blog posts (markdown). Subdirs OK — prefix with _ to hide from URL
  components/            # Astro components (.astro files)
  layouts/               # Page layouts (Layout, Main, PostDetails, AboutLayout)
  pages/                 # File-based routing (Astro pages)
  utils/                 # Utility functions and helpers
    og-templates/        # OG image templates (Satori-based)
    transformers/        # Shiki code block transformers
  styles/                # Global CSS (Tailwind)
  scripts/               # Client-side scripts (theme toggle etc.)
  assets/
    images/              # Optimized images (processed by Astro)
    icons/               # SVG icons
public/                  # Static assets (unprocessed)
```

## Key Conventions

### Blog Posts
- Location: `src/data/blog/` (markdown only, `.md`)
- Frontmatter: `title`, `description`, `pubDatetime` are REQUIRED
- Tags default to `["others"]` if omitted
- Use h2-h6 only — h1 is auto-generated from frontmatter `title`
- Images: use `@/assets/` alias or relative paths from the post, NOT `<img>` tags
- TOC: add `## Table of contents` where you want it to appear
- Slugs: auto-generated from filename, override with `slug` in frontmatter
- Subdirs with `_` prefix don't affect URL path

### Components
- All `.astro` files in `src/components/`
- Use Astro component syntax, not React/Vue
- Tailwind CSS 4 for styling (utility classes)

### Config
- Site metadata lives in `src/config.ts` (SITE constant)
- Content schema in `src/content.config.ts`
- Astro config in `astro.config.ts` (root)
- Base path is `/blog` — all routes are relative to this

### Images
- Optimized: `src/assets/images/` — use markdown syntax with `@/assets/` alias
- Static/unoptimized: `public/` — use absolute paths
- OG images: 1200x640, auto-generated via Satori if not specified in frontmatter

## NEVER

- Use h1 (`#`) in blog post body — title frontmatter is h1
- Use `<img>` tags for images in `src/assets/` — use markdown `![alt](@/assets/...)` syntax
- Put blog posts outside `src/data/blog/`
- Use `export default` in utility files
- Import from `src/` using absolute paths without the `@/` alias
- Modify the content collection schema without updating existing posts

## Dev Commands

```bash
pnpm dev          # Start dev server
pnpm build        # Type-check + build + pagefind index
pnpm preview      # Preview production build
pnpm format       # Prettier format
pnpm lint         # ESLint
```

## Routing Table (Cold Memory Injection)

| File path pattern              | Docs injected                     |
| ------------------------------ | --------------------------------- |
| `src/data/blog/**`             | `docs/content/blog-posts.md`      |
| `src/components/**`            | `docs/components/conventions.md`  |
| `src/config.ts`                | `docs/config/site-config.md`      |
| `src/content.config.ts`        | `docs/config/content-schema.md`   |
| `src/pages/**`                 | `docs/pages/routing.md`           |
| `src/utils/**`                 | `docs/config/utilities.md`        |
| `src/layouts/**`               | `docs/components/layouts.md`      |
| `astro.config.ts`              | `docs/config/site-config.md`      |

### Additional reference docs (not auto-injected, read on demand)

| Doc                              | When to read                                    |
| -------------------------------- | ----------------------------------------------- |
| `docs/content/seo.md`           | Publishing a post, setting up cross-posting, SEO |
| `docs/content/cross-posting.md` | Distributing a post to dev.to, HN, LinkedIn, etc |
| `docs/content/gotchas.md`       | Debugging build failures, formatting issues       |
| `docs/content/writing-guide.md` | Writing or reviewing a post before publishing     |

## Enforcement

PreToolUse (`inject-context.mjs`):
- Blocks new files in wrong directories
- Injects matching docs before every Edit/Write

PostToolUse (`arch-validate.sh`):
- Blocks h1 in blog posts
- Blocks `<img>` tags referencing `src/assets/`
- Blocks missing required frontmatter in blog posts
- Blocks `export default` in utils
