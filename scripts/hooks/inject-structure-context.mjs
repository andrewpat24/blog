import { readFileSync } from "fs";
import path from "path";

const BLOCKED_PATHS = [
  [/^src\/lib\//, "No top-level lib/ in this project. Utils go in src/utils/, components in src/components/."],
  [/^src\/services\//, "No services layer. This is a static blog — logic lives in src/utils/."],
  [/^src\/api\//, "No API routes. This is a fully static Astro site."],
  [/^src\/hooks\//, "No hooks directory. This is Astro, not React. Use src/utils/ for shared logic."],
  [/^src\/store\//, "No store/state management. This is a static site."],
  [/^src\/types\//, "Types go in the file that uses them, or in src/env.d.ts for global types."],
  [/^src\/data\/(?!blog\/)/, "Content files go in src/data/blog/ only."],
];

const VALID_SRC_DIRS = [
  "assets", "components", "config.ts", "constants.ts", "content.config.ts",
  "data", "env.d.ts", "layouts", "pages", "scripts", "styles", "utils",
];

export function structureCheck() {
  return {
    handle(ctx) {
      if (ctx.toolName !== "Write" || !ctx.isNewFile) return null;
      if (!ctx.filePath.startsWith("src/")) return null;

      for (const [pattern, guidance] of BLOCKED_PATHS) {
        if (pattern.test(ctx.filePath)) {
          return {
            block: true,
            message: `BLOCKED: ${ctx.filePath}\n${guidance}\nSee docs/content/blog-posts.md and AGENTS.md for the directory map.`,
          };
        }
      }

      // Check for unknown top-level dirs under src/
      const parts = ctx.filePath.replace("src/", "").split("/");
      const topLevel = parts[0];
      if (!VALID_SRC_DIRS.includes(topLevel)) {
        return {
          block: true,
          message: `BLOCKED: Unknown directory src/${topLevel}/. Valid directories: ${VALID_SRC_DIRS.join(", ")}. See AGENTS.md for the directory map.`,
        };
      }

      // Inject file placement context for valid new files
      const docsPath = path.join(ctx.projectRoot, "docs/content/blog-posts.md");
      try {
        const content = readFileSync(docsPath, "utf8");
        const injectMatch = content.match(/## Inject\n([\s\S]*?)(?=\n## |$)/);
        if (injectMatch) {
          ctx.additionalContext.push(`Context from docs/content/blog-posts.md:\n${injectMatch[1].trim()}`);
        }
      } catch { /* doc not found, skip */ }

      return null;
    },
  };
}
