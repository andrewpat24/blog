---
author: Andrew
pubDatetime: 2026-03-21T08:00:00Z
title: "Agent Convention Enforcement System"
slug: agent-convention-enforcement-system
featured: true
draft: false
tags:
  - ai
  - agents
  - claude-code
  - engineering
  - architecture
description: >
  A three-tier system that keeps AI coding agents aligned with your project's conventions
  through hot memory (always loaded), cold memory (injected on demand), and runtime
  enforcement (blocking violations after every edit). Agent-agnostic.
---

A three-tier system that keeps AI coding agents aligned with your project's conventions through hot memory (always loaded), cold memory (injected on demand), and runtime enforcement (blocking violations after every edit). Agent-agnostic.

---

## The Problem

AI coding agents don't read your docs. Even when they do, they suffer from **instruction fade-out** [[13]](#source-13) — conventions loaded at the start of a session gradually lose influence as the context window fills with conversation, code, and tool output. The result: agents write code that compiles, passes tests, and silently violates your architecture. Wrong import paths, bypassed repository layers, incorrect helpers, `any` instead of `unknown`. Each violation becomes precedent for the next agent.

This gets worse across sessions. Different agents in different sessions reach for different patterns — what TechDebt.guru calls **pattern divergence** [[15]](#source-15). One session uses the repository pattern, the next uses direct DB calls. Each looks correct individually. Collectively, your architecture is being rewritten by committee — a committee that never met.

The research is blunt: documentation alone achieves ~40% convention compliance [[3]](#source-3). Context quality degrades non-linearly past ~40% window fill [[6]](#source-6) [[11]](#source-11), and every frontier model tested shows this degradation — a phenomenon researchers now call **context rot** [[16]](#source-16). The gap between "code that works" and "code that follows conventions" is where architectural drift lives.

**In A/B testing, Haiku (Anthropic's cheapest model) jumped from 7.25/10 to 10/10 on convention compliance — same prompts, same codebase, only difference was the enforcement system.** The system turns model capability into a slider instead of a cliff.

See [Haiku A/B results](#haiku-ab-results) for code-level evidence.

---

## The Solution

```
┌─────────────────────────────────────────────────────────────────────┐
│ Tier 1: Hot Memory (AGENTS.md — loaded every session)              │
│   Layer map, dependency rules, routing table, dev commands          │
│   ~120-180 lines. Universal context regardless of task.            │
├─────────────────────────────────────────────────────────────────────┤
│ Tier 2: Cold Memory (leaf docs — injected on demand)               │
│   Domain-specific conventions, landmines, canonical examples        │
│   ~20-40 lines per doc. Only loaded when editing that domain.      │
├─────────────────────────────────────────────────────────────────────┤
│ Tier 3: Runtime Enforcement (hooks — every Edit/Write)             │
│   PreToolUse: middleware pipeline                                   │
│     1. Structure check — blocks new files in wrong dirs (Write)    │
│     2. Code context — injects ALL matching leaf docs before edit   │
│   PostToolUse: grep checks after edit, exit 2 blocks on violation  │
│   Stop: full convention review at session end                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Why three tiers?** Single-file manifests don't scale. Research measured 29% reduction in runtime and 17% reduction in tokens when context is structured as hot/cold memory. [[1]](#source-1) Runtime enforcement achieved 92% compliance vs 40% with documentation alone. [[3]](#source-3)

There's also a positional attention argument. LLMs attend strongly to the beginning and end of their context window but poorly to the middle — the "lost-in-the-middle" effect [[16]](#source-16). AGENTS.md loads at session start and gradually sinks into that low-attention middle zone as conversation accumulates. PreToolUse injection fires right before the edit, placing conventions at the recency-privileged end of the context window. Twenty lines in the right **position** outperform two hundred lines at the wrong *time*.

**How they work together:**

```
Edit/Write triggers
       │
       ▼
PreToolUse: inject-context.mjs (middleware pipeline)
  ├─ Middleware 1: structureCheck()
  │     Write to new src/ file?
  │       ├─ Known-wrong path? → exit 2, BLOCKED (agent never writes the file)
  │       ├─ New top-level dir under src/? → exit 2, BLOCKED
  │       └─ Valid path? → inject file-placement.md conventions
  ├─ Middleware 2: codeContext()
  │     All-matches routing: walks EVERY route, injects ALL matching docs
  │       └─ A domain repo file gets: service-patterns + repositories + domain doc
  └─ Combined context injected BEFORE the edit happens
       │
       ▼
Agent makes the edit (informed by structure + domain context)
       │
       ▼
PostToolUse: arch-validate.sh
  ├─ Blocking grep checks (exit 2 stops the agent)
  ├─ File placement checks (defense-in-depth for structureCheck)
  └─ Agent must fix violation before proceeding
```

**PreToolUse teaches and prevents** — the middleware pipeline runs two passes. First, `structureCheck()` catches file creation in wrong directories **before the file exists**. This is prevention, not cleanup — an agent writing to `src/utils/helpers.ts` is blocked with a redirect to the correct layer-specific `lib/` directory, and the file is never created. Second, `codeContext()` injects all matching domain conventions using all-matches routing. A domain repo file gets three docs: service-patterns, repositories, and the domain doc. No more blind spots from first-match-wins routing. [[14]](#source-14)

**PostToolUse enforces** — catches **structural** violations after the edit (`console.*`, `export default`, direct DB calls outside repos, cross-layer imports). Now also includes defense-in-depth file placement checks — if a file somehow gets past `structureCheck()`, the same wrong paths are caught post-write. The agent **always** self-corrects because the hook blocks it from proceeding until the violation is fixed. The gap between "usually" and "always" is where production systems fail. [[7]](#source-7) [[10]](#source-10) [[14]](#source-14)

Neither alone is sufficient. Together they cover both categories.

---

## Prerequisites

This system is a ratchet, not a cleanup tool. It prevents backsliding on conventions that already exist. [[10]](#source-10) [[12]](#source-12)

1. **Established conventions** — architecture layers, dependency rules, code patterns must be decided and documented before enforcement can reference them.
2. **Low existing violation counts** — blocking checks on files with 150 pre-existing violations will block every edit. Only add checks when existing hits are 0-2. `grep -rl 'pattern' src/ | wc -l` to count before adding.
3. **`.claude/settings.json` committed to git** — worktree agents inherit hooks from branch HEAD. Uncommitted hooks don't propagate.

---

## Implementation

### Step 1: Write AGENTS.md (hot memory)

~120-180 lines. Include: layer map, dependency rules (NEVER list), import aliases, routing table pointing to domain docs, enforcement summary. Exclude domain-specific detail.

### Step 2: Organize and write leaf docs (cold memory)

#### Directory structure

Organize docs along two axes: **layer** (where code lives architecturally) and **domain** (what business problem it solves). Each axis gets a directory. Each directory gets an `index.md` phonebook that routes readers to the right leaf doc.

```
docs/
  app/                          # Framework routing layer (e.g. Next.js, Remix)
    index.md                    # phonebook — "working on API routes? → api-routing.md"
    api-routing.md              # leaf doc
    frontend-routing.md         # leaf doc
  frontend/                     # Client/UI layer
    index.md
    components.md
    context.md
    hooks.md
  server/                       # Backend layer
    index.md
    service-patterns.md
    repositories.md
    integrations.md
    database.md
  shared/                       # Cross-layer utilities + types
    index.md
    types.md
    utils.md
  domain/                       # Business domains (cross-layer)
    index.md
    billing.md
    orders.md
    inventory.md
    users.md
    ...
  auth/                         # Auth (cross-layer, own axis)
    index.md
    frontend.md
    backend.md
  cross-cutting/                # Logging, error handling, enforcement
    index.md
    logging.md
    enforcement.md
  testing/                      # Test conventions
    index.md
    unit-integration.md
    e2e.md
```

#### Why two axes?

A file like `src/server/services/inventory/inventory-repo.ts` belongs to both the **server/repositories** layer and the **inventory** domain. Layer docs cover structural conventions (how repos work, what the query builder is, single-table rule). Domain docs cover business conventions (deletion cascades, computed fields, cross-domain side effects).

The routing table in `inject-context.mjs` decides which docs get injected for a given file path. With all-matches routing, every matching rule fires — domain-specific routes AND layer catchalls both inject. This means an inventory repo file gets `inventory.md` AND `repositories.md` AND `service-patterns.md` in a single context block. General docs inject first (service patterns, repositories), domain doc injects last — so the domain-specific context is closest to the recency-privileged end of the window when the agent writes code.

#### Index docs (phonebooks)

Index docs are not auto-injected. They're lookup tables for humans and agents who need to find the right leaf doc. Format:

```markdown
# Server
| Working on...                                                  | Read                |
| -------------------------------------------------------------- | ------------------- |
| Service patterns (layering, barrel exports, file organization) | service-patterns.md |
| Repositories (base class, queries, single-table rule)          | repositories.md     |
| External integrations (third-party APIs, webhooks)             | integrations.md     |
| Database (clients, connection patterns, migrations)            | database.md         |
```

#### Leaf doc format

Each leaf doc has two sections — `## Inject` (auto-injected, 20-40 lines) and `## Reference` (full detail, read on demand):

```markdown
# Inventory Domain

Last verified: 2026-02-27

## Inject

Safe export pattern — the barrel (`index.ts`) omits `insert`, `update`, `remove` from
the repo export. Direct repo writes bypass orchestration (notifications, cache invalidation,
dependent cleanup). All mutations go through service-level functions.

Deletion cascades across domains — `deleteItem()` archives all related pricing records,
removes the item from every referencing bundle, then deletes the record. Miss a step and
you get orphaned data.

Unit conversion requires density — if `unit_of_measurement` is volumetric (gal, L),
records must have `density` and `density_unit` for weight conversion. Without density,
conversion silently falls back to original values (no error thrown).

Canonical examples:

- Safe export: `src/server/services/inventory/index.ts:35-36`
- Deletion cascade: `src/server/services/inventory/index.ts:272-295`
- Unit conversion: `src/server/services/inventory/inventory-pricing.ts`

## Reference

[Full architecture, all the detail — not auto-injected]
```

> **Note on "All DB access goes through repo functions" one-liners:** Earlier versions of this system added a one-liner at the top of every domain inject section to compensate for domain routes outranking `repositories.md` (Gotcha #5). With all-matches routing, domain repo files now receive `repositories.md` directly — the one-liner is redundant. Remove it; the doc that actually covers repos in full detail now injects alongside the domain doc.

#### What goes in `## Inject` (the discoverability filter)

Before including anything, ask: **can the agent figure this out by reading the code?** If yes, omit it. [[9]](#source-9)

**Include:** silent failures, cross-domain side effects, state machine traps, computed-not-stored fields, deletion cascades, non-obvious required helpers (e.g. a project-specific validation helper over a generic one), canonical example file paths with line numbers.

**Exclude:** what functions do, tech stack descriptions, standard patterns, anything discoverable from imports or directory structure. Every line in an inject section signals something confusing enough to trip an agent — probably confusing enough to trip a human too. When you fix the code to make it obvious, remove the instruction. Goal: leaf docs shrink over time. [[9]](#source-9)

**Sizing:** Inject 20-40 lines (hard limit 50). Reference has no limit. Split doc if total exceeds ~250 lines — the phonebook pattern is recursive. [[5]](#source-5)

**Style:** Positive framing — "Use X for Y" not "Don't use X." Negative framing anchors the wrong pattern (the "pink elephant" problem). Reserve "NEVER" for dangerous violations only. End with canonical file paths — real examples beat prose descriptions. [[4]](#source-4) [[9]](#source-9)

### Step 3: Write inject-context.mjs (PreToolUse hook)

The PreToolUse hook is implemented as a **middleware pipeline** — an orchestrator that runs two middlewares in sequence, each responsible for a different concern. This mirrors the same pattern you'd use for HTTP middleware (auth, rate-limit, logging): factories that return handler objects, run by a shared pipeline runner.

#### Pipeline architecture

```
inject-context.mjs          ← orchestrator entry point
scripts/hooks/
  base.mjs                  ← buildContext() + runPipeline()
  inject-structure-context.mjs  ← structureCheck() middleware
  inject-code-context.mjs       ← codeContext() middleware
```

The orchestrator wires the pipeline:

```jsx
// inject-context.mjs
import { buildContext, runPipeline } from './hooks/base.mjs';
import { structureCheck } from './hooks/inject-structure-context.mjs';
import { codeContext } from './hooks/inject-code-context.mjs';

const PIPELINE = [
  structureCheck(),   // runs first — blocks bad paths, injects placement context
  codeContext(),      // runs second — injects all matching domain docs
];

let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => { input += chunk; });
process.stdin.on('end', () => {
  let ctx;
  try { ctx = buildContext(input); } catch { process.exit(0); }
  runPipeline(ctx, PIPELINE);
});
```

`buildContext()` parses stdin JSON and resolves the file path — stripping `$CLAUDE_PROJECT_DIR` from absolute paths (see Gotcha #1), checking whether the file exists on disk (determines `ctx.isNewFile`), and reading `tool_name`. The pipeline runner calls each middleware in order; if any returns `{ block: true }`, it exits 2 immediately without running subsequent middlewares.

#### Middleware 1: structureCheck()

Fires **only on `Write` to new files** in `src/`. Edits and overwrites pass through — the file is already placed.

Two checks in order:

1. **Blocked paths** — an array of `[regex, guidance]` pairs for known-wrong locations. Covers: layer-less top-level dirs (`src/utils/`, `src/components/`, etc.), `utils/` inside valid layers, layer-confused placements (`src/frontend/services/`), typo/singular variants (`src/frontend/component/`), and standalone repositories directory.
2. **New top-level directory** — any `src/<X>/` path where `X` is not `app`, `frontend`, `server`, or `shared` is blocked.

On a blocked path: exit 2 with a `BLOCKED:` message explaining the correct location and pointing to `docs/cross-cutting/file-placement.md`. On a valid new path: inject the `## Inject` section of `file-placement.md` into context — the agent sees the full directory map before it writes the file.

#### Middleware 2: codeContext()

Walks the full ROUTES array and injects **every** matching doc — all-matches routing, not first-match-wins. This eliminates the blind spot where domain routes outranked layer routes (see resolved Gotcha #5).

Order still matters for the output — general docs inject first, specific docs last. With recency bias, the most specific doc ends up closest to where the agent is working:

```
general→specific injection order example for billing-repo.ts:
  1. service-patterns.md   (broad layer catchall — always useful background)
  2. repositories.md       (layer-specific — repo query conventions)
  3. billing.md            (domain-specific — billing landmines and side effects)
```

For shared/cross-layer files, use filename patterns to route to the right domain doc. A file like `src/shared/domain/billing-utils.ts` can match on the `billing-` prefix and route to `docs/domain/billing.md`, even though it lives in the shared layer.

**Key behaviors of the full pipeline:**

- Strips `$CLAUDE_PROJECT_DIR` from absolute paths before pattern matching (see Gotcha #1)
- All-matches routing — every matching route injects, general→specific ordering
- Structure enforcement fires before code context (no point injecting a doc for a file that's about to be blocked)
- No dedup — fires every edit (inject sections are trivial token cost, caching broke subagents)
- Extracts only `## Inject` from each matched doc, falls back to full doc if section not found
- Unmatched `src/` files trigger "stop and ask" alert

### Step 4: Write arch-validate.sh (PostToolUse hook)

Grep checks on modified files, exits 2 on violations. Template:

```bash
#!/usr/bin/env bash

INPUT=$(cat)
ABS_FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

# CRITICAL: Strip project root — same reason as inject-context
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
FILE="${ABS_FILE#"$PROJECT_ROOT/"}"

VIOLATIONS=""

# Pattern match on $FILE (relative), grep on $ABS_FILE (absolute)
# if [[ "$FILE" == src/some/path/* ]]; then
#   grep -q "bad_pattern" "$ABS_FILE" 2>/dev/null && \
#     VIOLATIONS+="What's wrong — how to fix\n"
# fi

if [ -n "$VIOLATIONS" ]; then
  echo -e "Arch violations in $FILE:\n$VIOLATIONS" >&2
  exit 2
fi

exit 0
```

**Exit codes:** `0` = clean. `2` = blocking (stderr sent to agent as feedback). Other = non-blocking. **PostToolUse does NOT support `additionalContext` JSON output** (GitHub #18427). Exit 2 + stderr is the only feedback mechanism.

As an example, our production implementation has 15 blocking checks and 1 non-blocking warning. Yours will differ — the point is to codify your project's specific rules:

```
| Check                           | Category        | What it catches                                |
|---------------------------------|-----------------|------------------------------------------------|
| Server imports in frontend code | Layer boundary  | Frontend importing server-only modules         |
| Frontend imports in server code | Layer boundary  | Server importing client/UI modules             |
| fetch() in view components      | Layer boundary  | Direct data fetching in views — belongs in hooks |
| Direct DB calls outside repos   | Data access     | Service bypassing repository layer             |
| Server/frontend imports in shared | Layer boundary| Shared layer depending on I/O layers           |
| Browser APIs in shared          | Layer boundary  | document.*, window.*, localStorage in shared   |
| Deprecated import aliases       | Migration       | Old import paths that should use new aliases   |
| Deep imports bypassing barrels  | Encapsulation   | Importing internal files instead of barrel index |
| Repo-to-repo imports            | Data access     | Cross-table joins belong in services, not repos |
| Repo importing a service        | Data access     | Repos are a lower layer than services          |
| console.* (excl. tests, logger) | Code quality    | Use structured logger instead                  |
| fetch() in services             | Code quality    | External API calls belong in integrations layer |
| export default (excl. framework files) | Code quality | Named exports only                         |
| Barrel imports from hooks dir   | Code quality    | Import by file path, not barrel                |
| Wrong validation helper pattern | Code quality    | Use project-specific helper instead of generic |
| Known-wrong top-level dirs      | File placement  | src/utils/, src/components/, etc.              |
| New unknown top-level dir       | File placement  | src/<anything>/ outside the four valid layers  |
| Layer-confused paths            | File placement  | src/frontend/services/, src/server/hooks/, etc.|
| Warning as any / : any (non-blocking) | Code quality   | Prefer unknown with type guards                |
```

The placement checks (last three rows) are deliberately redundant with the `structureCheck()` middleware. PreToolUse catches bad paths at creation time, PostToolUse catches them if a file somehow ends up in a wrong location after the fact (e.g. manual moves, Bash commands that bypass the Write hook). Defense in depth.

### Step 5: Wire hooks in .claude/settings.json

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "node $CLAUDE_PROJECT_DIR/scripts/inject-context.mjs" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "bash $CLAUDE_PROJECT_DIR/scripts/arch-validate.sh" }
        ]
      }
    ]
  }
}
```

Use `$CLAUDE_PROJECT_DIR` — resolves correctly in subagents and worktrees.

### Step 6: Commit .claude/settings.json to git

Required for worktree agents. `git worktree add` checks out from branch HEAD — uncommitted changes don't propagate.

---

## Testing Your Implementation

Testing has three levels: script-level unit tests, blind injection exams, and live convention scoring. All scoring is deterministic (grep-based, no LLM judgment).

### Level 1: Script unit tests

Validate that inject-context routes correctly and arch-validate catches what it should.

```bash
# Test structure enforcement (should BLOCK with exit 2)
echo '{"tool_name":"Write","tool_input":{"file_path":"src/utils/helpers.ts"}}' \
  | CLAUDE_PROJECT_DIR=$(pwd) node scripts/inject-context.mjs 2>&1; echo "Exit: $?"

# Test all-matches routing (should return 3 docs for a domain repo file)
echo '{"tool_name":"Edit","tool_input":{"file_path":"'"$(pwd)"'/src/server/services/billing/billing-repo.ts"}}' \
  | CLAUDE_PROJECT_DIR=$(pwd) node scripts/inject-context.mjs 2>/dev/null \
  | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')); const docs=(d.hookSpecificOutput?.additionalContext||'').match(/Context from docs\/[^:]+:/g)||[]; console.log(docs.length + ' docs:', docs)"

# Test arch-validate placement checks (use absolute path!)
echo '{"tool_input":{"file_path":"'"$(pwd)"'/src/utils/bad.ts"}}' \
  | CLAUDE_PROJECT_DIR=$(pwd) bash scripts/arch-validate.sh 2>&1; echo "Exit: $?"

# Run full test harnesses (204 total tests across all three)
bash scripts/test-inject-context.sh              # 83 routing + all-matches + failure mode tests
bash scripts/test-inject-structure-context.sh    # 55 structure enforcement tests
bash scripts/eval-arch-validate.sh               # 66 arch-validate tests (human-readable)
bash scripts/eval-arch-validate.sh --json        # machine-readable
```

### Level 2: Blind injection exam

Tests whether injected context actually reaches agents and is usable. You'll write an exam, then launch fresh subagents across all model tiers to take it.

#### Step 1: Write the exam

Pick 3-5 domains your routing table covers. For each domain, pick one file that routes to that domain's leaf doc. Write 2 questions per domain whose answers live in the target doc's `## Inject` section. **Pre-verify every question** — read the inject section and confirm the answer is there. Questions about content that isn't in the inject section test your routing, not your injection.

Good questions target non-obvious conventions: "What helper must be used for X?", "What happens when Y is deleted — what cascades?", "What pattern does Z use and why?"

#### Step 2: Build + launch the exam agents

Use the following prompt to launch one subagent per model tier. Replace the `[bracketed]` sections with your actual domains, files, and questions.

```
You are taking a blind exam to test whether the PreToolUse context injection
system works. You have NO prior context about this codebase. Your ONLY source
of domain knowledge is whatever gets injected via hooks when you edit files.

RULES:
1. For each section below, edit the specified file (add `// exam` as the first
   line using the Edit tool, then remove it with a second Edit)
2. After each edit, you will receive injected context via a system-reminder
   tagged "PreToolUse:Edit hook additional context"
3. Answer each question using ONLY that injected context
4. Do NOT read any docs/ files or use prior knowledge
5. If the injection didn't cover a question, write "NOT IN INJECTION"
6. After each answer, quote the exact injected text you're citing

GRADING:
- Correct answer with exact citation: 2 points
- Correct answer without citation: 1 point
- "NOT IN INJECTION" when truly not covered: 1 point (honesty bonus)
- Wrong answer: 0 points
- Fabricated answer presented as from injection: -1 point

Maximum score: [N] points ([N/2] questions x 2 points)

---

## Section A: [Domain Name]
**Edit file:** `[path/to/file-in-this-domain.ts]`

**Q1:** [Question whose answer is in the inject section]

**Q2:** [Question whose answer is in the inject section]

---

## Section B: [Domain Name]
**Edit file:** `[path/to/file-in-this-domain.ts]`

**Q3:** [Question whose answer is in the inject section]

**Q4:** [Question whose answer is in the inject section]

---

[...repeat for each domain section...]

---

## Answer Sheet

Write answers in this format:

### Q[N]
**Answer:** [your answer]
**Citation:** "[exact text from injection]"

After all questions, add:

## Score Self-Assessment
- Questions answered from injection: X/[total]
- Questions where injection was missing: X/[total]
- Confidence that answers came from injection only: X/5

Write your results to `[output-path]-[model-name].md`
```

Launch three subagents in parallel — one per model tier (e.g. Opus, Sonnet, Haiku). Each subagent must be a fresh context with no shared history. The key constraint: subagents share a session ID, so if you have any dedup caching, all three will race for the cache and only one will receive injection. This is why we removed dedup entirely.

**Note on subagent testing:** Hook injection does NOT propagate to Agent SDK worktree subagents — `additionalContext` surfaces in the parent session only. These results were obtained by running each model as a top-level `claude` CLI session where hooks fire correctly.

### Level 3: Convention scoring on real edits

Score actual source files against conventions after agents edit them.

If you build a convention scorer (grep-based, no LLM judgment), you can automate this:

```bash
# Score a single file against domain-appropriate checks
bash scripts/eval-score-conventions.sh src/shared/schemas/some-schema.ts

# Score with JSON output for aggregation
bash scripts/eval-score-conventions.sh --json src/shared/schemas/some-schema.ts

# Run negative fixture self-tests (compliant version passes, non-compliant fails)
bash scripts/eval-score-conventions.sh --self-test
```

The scorer should be domain-aware — different checks apply to schemas vs services vs repos vs hooks vs views vs shared files.

### Context decay test (15-file session)

The full protocol is designed to measure whether compliance degrades over a long editing session. 15 sequential edits across schemas, services, hooks, views, repos, and shared domain files. Each task tempts a specific violation.

**Our results: both Haiku and Sonnet scored 108/108 — zero decay.** Compliance at file #15 was identical to file #1. The enforcement system prevents the context window degradation that research predicts past ~40% fill. [[6]](#source-6) [[11]](#source-11)

```
| Model     | Total tokens | Tool uses | Wall time | Tokens/file |
|----------|--------------|-----------|-----------|-------------|
| Haiku 4.5| 136k         | 41        | 2m 37s    | ~9k         |
| Sonnet 4.6| 72k         | 40        | 3m 23s    | ~4.8k       |
```

---

## Gotchas

### 1. Absolute path mismatch (silent total failure)

Claude Code sends `/Users/.../src/server/...` but regex routes match `^src/server/...`. Without stripping the project root, zero routes match. **This silently disabled ALL enforcement** until caught. Both scripts must strip `$CLAUDE_PROJECT_DIR`:

```jsx
// inject-context.mjs
const projectRoot = process.env.CLAUDE_PROJECT_DIR || process.cwd();
const filePath = rawPath.startsWith(projectRoot)
  ? rawPath.slice(projectRoot.length + 1)
  : rawPath;
```

```bash
# arch-validate.sh
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
FILE="${ABS_FILE#"$PROJECT_ROOT/"}"
```

### 2. Worktree hook propagation

`.claude/settings.json` must be committed. `git worktree add` checks out from branch HEAD. No commit = no hooks in worktree = silent enforcement bypass.

### 3. Dedup cache breaks subagent injection

Parallel subagents share a session ID. A per-session dedup cache means only the first agent to edit a domain gets injection. Fix: no cache. 20-40 lines per injection is trivial.

### 4. PostToolUse additionalContext is dead code

PostToolUse hooks don't support `additionalContext` JSON (GitHub #18427). Exit 2 + stderr is the only feedback mechanism.

### 5. ~~Route priority creates blind spots~~ (resolved)

~~Domain routes outrank layer routes (first match wins). A domain repo file matches the domain doc but never reaches `repositories.md`. Fix: add key conventions from outranked docs as one-liners in the winning doc's inject section.~~

**Resolved with all-matches routing.** The `codeContext()` middleware now walks the full ROUTES array and injects every matching doc. A domain repo file gets service-patterns + repositories + the domain doc in a single context block. No one-liners needed. If you're reading this in the context of the older first-match-wins implementation, the fix is to migrate to the pipeline architecture described in Step 3.

---

## Haiku A/B Results

Two multi-file features built by Haiku (Anthropic's cheapest model), each built twice: once with all three enforcement tiers, once with no hooks. Same model, same prompts, same codebase.

### Feature A: Preferences API (schema + repo + service + route + tests)

**With enforcement 10/10 | Without enforcement 7/10**

With enforcement — project-specific validation helper used correctly:

```tsx
export const preferencesQuerySchema = z.object({
  enabled_only: z.stringbool().optional()   // project helper for boolean query params
```

Without enforcement — generic approach (wrong for this project):

```tsx
export const preferencesQuerySchema = z.object({
  enabled_only: z.coerce.boolean().optional(),  // works, but violates convention
});
```

With enforcement — repo method fully typed:

```tsx
async upsertPreferences(
  userId: string, category: string,
  preferences: { email: boolean; in_app: boolean; sms: boolean }
): Promise<PreferencesRow> {
```

Without enforcement — `any` (twice):

```tsx
async upsert(userId: string, category: string, preferences: any): Promise<Row> {
  return this.insert({ /* ... */ } as any);
```

### Feature B: Domain comparison utility (types + shared util + hook + tests)

**With enforcement 10/10 | Without enforcement 7.5/10**

With enforcement — `unknown` throughout:

```tsx
export interface FieldDiff {
  fieldName: string;
  oldValue: unknown;
  newValue: unknown;
}
function areValuesEqual(a: unknown, b: unknown): boolean {
```

Without enforcement — `any` (4 instances):

```tsx
export interface FieldChange<T = any> {
function areValuesEqual(value1: any, value2: any): boolean {
function formatValue(value: any): string {
```

### Summary

| Feature | Without enforcement | With enforcement | Violations prevented |
| --- | --- | --- | --- |
| Preferences API | **7/10** (3 violations) | **10/10** | Wrong validation helper, generic schema name, **any** params |
| Comparison util | **7.5/10** (4 violations) | **10/10** | **any** in types (x1), **any** in domain utils (x3) |
| **Average** | **7.25/10** | **10/10** | **7** violations prevented |

The enforcement system's value is in conventions that **can't be inferred from the codebase**: which helper to use, `unknown` over `any`, naming patterns. Without explicit injection, Haiku reaches for the generic/obvious approach every time. [[4]](#source-4) [[9]](#source-9)

### Three categories of agent mistakes

| Category | Example | Caught by | Success rate |
| --- | --- | --- | --- |
| **Structural** | `console.log`, `export default`, cross-layer imports | PostToolUse grep → exit 2 | **100%** — always self-corrects |
| **Pattern** | Wrong validation helper, `any` instead of `unknown` | PreToolUse injection | **~95%** with injection (up from ~50% without) |
| **Judgment** | Error handling strategy, wrong abstraction level | Model capability only | **~70%** — model-limited |

---

## Research Sources

| # | Article | Key insight |
| --- | --- | --- |
| <a id="source-1"></a>**[1]** | [Codified Context](https://arxiv.org/abs/2602.20478) (arxiv, Feb 2026) | Hot/cold memory tiers. 29% runtime reduction, 17% token reduction. |
| <a id="source-2"></a>**[2]** | [Project Structure for AI](https://developertoolkit.ai/en/shared-workflows/context-management/file-organization/) (developertoolkit.ai) | Every irrelevant line is wasted context. |
| <a id="source-3"></a>**[3]** | [Enforce Architectural Patterns](https://agiflow.io/blog/enforce-ai-architectural-patterns-mcp/) (Agiflow) | 92% compliance with runtime enforcement vs 40% with docs alone. |
| <a id="source-4"></a>**[4]** | [Structure Beats Prose](https://dev.to/stefanve/structure-beats-prose-specs-for-coding-agents-that-actually-work-eln) (Stefan van Egmond) | Canonical file paths > prose descriptions. |
| <a id="source-5"></a>**[5]** | [Refactoring Agent Skills](https://dev.to/superorange0707/refactoring-agent-skills-from-context-explosion-to-a-fast-reliable-workflow-5hg6) (dev.to) | 200-line rule. Workflow-centric > tool-centric naming. |
| <a id="source-6"></a>**[6]** | [Coding Agents First-Class](https://dev.to/somedood/coding-agents-as-a-first-class-consideration-in-project-structures-2a6b) (dev.to) | 40% context window rule — degradation past 40%. |
| <a id="source-7"></a>**[7]** | Architecture Enforced Not Documented (LinkedIn) | Machine-readable rules delivered at the right moment. |
| <a id="source-8"></a>**[8]** | [Why AI Needs Structured Code](https://dev.to/matthew_anderson/why-ai-needs-structured-code-1efb) (dev.to) | Structure enables AI to navigate directly. |
| <a id="source-9"></a>**[9]** | [Stop Using /init for AGENTS.md](https://addyosmani.com/blog/agents-md/) (Addy Osmani) | Discoverability filter. Pink elephant problem. Docs as debt signal. |
| <a id="source-10"></a>**[10]** | [Why AI Agents Need External Enforcement, Not Better Prompts](https://paircoder.ai/blog/enforcement-not-prompts/) (PairCoder) | "System reliability is a property of the architecture, not the model." |
| <a id="source-11"></a>**[11]** | [Deterministic AI Orchestration](https://www.praetorian.com/blog/deterministic-ai-orchestration-a-platform-architecture-for-autonomous-development/) (Praetorian) | Context Trap: token cost is linear but attention degradation is non-linear. |
| <a id="source-12"></a>**[12]** | [Defense in Depth for AI-Assisted Development](https://brooksmcmillin.com/blog/coding-safer-with-llms/) (Brooks McMillin) | Progressive adoption: pre-commit hooks first, review agents second, CI third. |
| <a id="source-13"></a>**[13]** | [Building AI Coding Agents for the Terminal](https://arxiv.org/abs/2603.05344) (arxiv, Mar 2026) | "Instruction fade-out" — conventions lose influence as context fills. |
| <a id="source-14"></a>**[14]** | [Claude Code Hooks: The Deterministic Control Layer](https://www.dotzlaw.com/insights/claude-hooks/) (Dotzlaw Consulting) | The gap between "usually" and "always" is where production systems fail. |
| <a id="source-15"></a>**[15]** | [AI Architecture Drift: Detection & Fix](https://techdebt.guru/ai-architecture-drift/) (TechDebt.guru) | Pattern divergence — different AI sessions suggest different approaches. |
| <a id="source-16"></a>**[16]** | [What Is Context Rot? Why LLMs Degrade as Context Grows](https://www.morphllm.com/context-rot) (Morph/Chroma) | Lost-in-the-middle: 30%+ performance drop. |
