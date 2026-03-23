import { readFileSync } from "fs";
import path from "path";

const ROUTES = [
  // Blog posts get blog-posts + writing guide + SEO context
  { pattern: /^src\/data\/blog\//, docs: ["docs/content/blog-posts.md", "docs/content/writing-guide.md", "docs/content/seo.md"] },
  // Components
  { pattern: /^src\/components\//, docs: ["docs/components/conventions.md"] },
  // Layouts
  { pattern: /^src\/layouts\//, docs: ["docs/components/layouts.md"] },
  // Config files
  { pattern: /^src\/config\.ts$/, docs: ["docs/config/site-config.md"] },
  { pattern: /^astro\.config\.ts$/, docs: ["docs/config/site-config.md", "docs/content/gotchas.md"] },
  { pattern: /^src\/content\.config\.ts$/, docs: ["docs/config/content-schema.md", "docs/content/gotchas.md"] },
  // Pages + routing
  { pattern: /^src\/pages\//, docs: ["docs/pages/routing.md"] },
  // OG image templates get SEO context
  { pattern: /^src\/utils\/og-templates\//, docs: ["docs/config/utilities.md", "docs/content/seo.md"] },
  // Utilities
  { pattern: /^src\/utils\//, docs: ["docs/config/utilities.md"] },
  // GitHub Actions / deployment
  { pattern: /^\.github\//, docs: ["docs/content/gotchas.md"] },
];

function extractInjectSection(content) {
  const match = content.match(/## Inject\n([\s\S]*?)(?=\n## |$)/);
  return match ? match[1].trim() : content;
}

export function codeContext() {
  return {
    handle(ctx) {
      const matchedDocs = new Set();

      // All-matches routing — walk every route
      for (const route of ROUTES) {
        if (route.pattern.test(ctx.filePath)) {
          for (const doc of route.docs) {
            matchedDocs.add(doc);
          }
        }
      }

      for (const docPath of matchedDocs) {
        const fullPath = path.join(ctx.projectRoot, docPath);
        try {
          const content = readFileSync(fullPath, "utf8");
          const injected = extractInjectSection(content);
          ctx.additionalContext.push(`Context from ${docPath}:\n${injected}`);
        } catch { /* doc not found, skip */ }
      }

      return null;
    },
  };
}
