# Layout Conventions

Last verified: 2026-03-21

## Inject

Layouts live in `src/layouts/`. Four layouts exist:
- `Layout.astro` — base HTML shell (head, meta, scripts). All pages use this.
- `Main.astro` — main content wrapper with header/footer. Most pages use this.
- `PostDetails.astro` — single blog post view with TOC, share links, back button.
- `AboutLayout.astro` — about page layout.

When creating a new page, wrap it in `Main` (which wraps `Layout` internally).
Do not create new layouts unless the existing four genuinely can't handle the use case.

Canonical examples:
- Page using Main: `src/pages/index.astro`
- Post rendering: `src/layouts/PostDetails.astro`
