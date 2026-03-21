import { existsSync } from "fs";
import path from "path";

export function buildContext(input) {
  const parsed = JSON.parse(input);
  const toolName = parsed.tool_name;
  const rawPath = parsed.tool_input?.file_path || "";

  const projectRoot = process.env.CLAUDE_PROJECT_DIR || process.cwd();
  const filePath = rawPath.startsWith(projectRoot)
    ? rawPath.slice(projectRoot.length + 1)
    : rawPath;

  const isNewFile = !existsSync(rawPath);

  return { toolName, filePath, rawPath, projectRoot, isNewFile, additionalContext: [] };
}

export function runPipeline(ctx, middlewares) {
  for (const mw of middlewares) {
    const result = mw.handle(ctx);
    if (result?.block) {
      process.stderr.write(result.message + "\n");
      process.exit(2);
    }
  }

  if (ctx.additionalContext.length > 0) {
    const output = {
      hookSpecificOutput: {
        additionalContext: ctx.additionalContext.join("\n\n---\n\n"),
      },
    };
    process.stdout.write(JSON.stringify(output));
  }

  process.exit(0);
}
