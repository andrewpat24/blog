import { buildContext, runPipeline } from "./hooks/base.mjs";
import { structureCheck } from "./hooks/inject-structure-context.mjs";
import { codeContext } from "./hooks/inject-code-context.mjs";

const PIPELINE = [
  structureCheck(),
  codeContext(),
];

let input = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => { input += chunk; });
process.stdin.on("end", () => {
  let ctx;
  try { ctx = buildContext(input); } catch { process.exit(0); }
  runPipeline(ctx, PIPELINE);
});
