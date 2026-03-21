import { readFileSync } from "fs";
import path from "path";

const ROUTES = [
  { pattern: /^src\/data\/blog\//, docs: ["docs/content/blog-posts.md"] },
  { pattern: /^src\/components\//, docs: ["docs/components/conventions.md"] },
  { pattern: /^src\/layouts\//, docs: ["docs/components/layouts.md"] },
  { pattern: /^src\/config\.ts$/, docs: ["docs/config/site-config.md"] },
  { pattern: /^astro\.config\.ts$/, docs: ["docs/config/site-config.md"] },
  { pattern: /^src\/content\.config\.ts$/, docs: ["docs/config/content-schema.md"] },
  { pattern: /^src\/pages\//, docs: ["docs/pages/routing.md"] },
  { pattern: /^src\/utils\//, docs: ["docs/config/utilities.md"] },
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
