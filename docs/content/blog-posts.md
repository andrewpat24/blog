# Blog Posts

Last verified: 2026-03-21

## Inject

Posts live in `src/data/blog/` as markdown (`.md`) files. Subdirectories are allowed —
prefix with `_` to exclude the dir name from the URL slug.

Required frontmatter fields — every post MUST have all three:
```yaml
---
title: "Post Title"
description: "One-line description for SEO and excerpts"
pubDatetime: 2026-03-21T00:00:00Z
---
```

Optional but common:
```yaml
tags: ["ai", "architecture"]     # defaults to ["others"]
featured: true                    # show on homepage featured section
draft: true                       # hide from production
slug: custom-slug                 # overrides filename-based slug
ogImage: ../../assets/images/og.png  # or remote URL
```

Heading hierarchy — the post title in frontmatter renders as h1. Use only h2 (`##`)
through h6 in the post body. Never use `# Heading` in post content.

Table of contents — add `## Table of contents` (exact text) where you want the TOC.
The remark-toc plugin generates it automatically.

Images in posts — use markdown syntax with the `@/assets/` alias:
```md
![alt text](@/assets/images/example.jpg)
```
Do NOT use `<img>` tags for images in `src/assets/` — Astro won't optimize them.
For `public/` images, use absolute paths: `![alt](/assets/images/example.jpg)`

Code blocks — Shiki syntax highlighting with transformers:
- `file="filename.ts"` annotation to show filename header
- `// [!code highlight]` for line highlighting
- `// [!code ++]` / `// [!code --]` for diff notation

Canonical examples:
- Frontmatter: `src/data/blog/adding-new-post.md:1-14`
- Content schema: `src/content.config.ts:7-23`

## Reference

See the full Astro Paper docs on adding posts: `src/data/blog/adding-new-post.md`
