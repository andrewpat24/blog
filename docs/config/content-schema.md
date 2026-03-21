# Content Collection Schema

Last verified: 2026-03-21

## Inject

The blog content collection is defined in `src/content.config.ts`. It uses Astro's
`glob` loader to find all `.md` files in `src/data/blog/` (excluding `_`-prefixed filenames).

Schema fields — if you add a new frontmatter field, it MUST be added here first:
```ts
z.object({
  author: z.string().default(SITE.author),
  pubDatetime: z.date(),               // REQUIRED
  modDatetime: z.date().optional().nullable(),
  title: z.string(),                    // REQUIRED
  featured: z.boolean().optional(),
  draft: z.boolean().optional(),
  tags: z.array(z.string()).default(["others"]),
  ogImage: image().or(z.string()).optional(),
  description: z.string(),             // REQUIRED
  canonicalURL: z.string().optional(),
  hideEditPost: z.boolean().optional(),
  timezone: z.string().optional(),
})
```

Adding a new field: add it to this schema with `.optional()` and a sensible default
so existing posts don't break. Then update `docs/content/blog-posts.md` to document it.

Canonical examples:
- Schema definition: `src/content.config.ts:7-23`
