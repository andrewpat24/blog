# Component Conventions

Last verified: 2026-03-21

## Inject

All components are `.astro` files in `src/components/`. Use Astro component syntax —
no React, Vue, or other framework components unless explicitly adding an integration.

Styling uses Tailwind CSS 4 utility classes. No CSS modules, no styled-components.

Props are typed inline in the component's frontmatter script:
```astro
---
interface Props {
  title: string;
  isActive?: boolean;
}
const { title, isActive = false } = Astro.props;
---
```

Existing components to reuse (don't recreate):
- `Card.astro` — blog post card
- `Tag.astro` — tag pill/badge
- `Datetime.astro` — formatted date display
- `LinkButton.astro` — styled link as button
- `ShareLinks.astro` — social share buttons
- `Pagination.astro` — page navigation
- `Breadcrumb.astro` — breadcrumb navigation
- `Header.astro` / `Footer.astro` — site chrome

Canonical examples:
- Props typing: `src/components/Card.astro`
- Tailwind usage: `src/components/Tag.astro`
