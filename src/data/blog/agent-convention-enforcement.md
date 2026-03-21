---
author: Andrew
pubDatetime: 2026-03-21T08:00:00Z
title: "The Three-Tier System That Keeps AI Agents On Your Architecture"
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
  AI agents write code that compiles, passes tests, and silently violates your architecture.
  Here's a three-tier enforcement system — hot memory, cold memory, and runtime hooks —
  that took Haiku from 7.25/10 to a perfect 10 on convention compliance.
---

Your agents are lying to you.

Not intentionally. They write code that compiles. It passes tests. The PR looks reasonable. But it's using `any` where you mandated `unknown`, calling the DB directly instead of going through the repo layer, picking the generic validation helper instead of the project-specific one you spent two weeks getting right.

Each violation looks like a small thing. Each becomes precedent for the next agent session. Six months later your architecture has been quietly rewritten by a committee that never met.

This is a documented phenomenon. Documentation alone achieves about 40% convention compliance. Context quality degrades non-linearly past ~40% window fill — researchers now call it *context rot*. And it gets worse across sessions: different agents in different windows reach for different patterns. Pattern divergence. The gap between "code that works" and "code that follows conventions" is exactly where architectural drift lives.

I built a three-tier system to close that gap. The punchline: **Haiku (Anthropic's cheapest model) jumped from 7.25/10 to 10/10 on convention compliance** — same prompts, same codebase, same model. Only difference was the enforcement system. The system turns model capability into a dial, not a cliff.

## Table of contents

## The Problem in Concrete Terms

Two A/B tests on real features, Haiku with and without enforcement:

**Without enforcement:**
```tsx
async upsert(userId: string, category: string, preferences: any): Promise<Row> {
  return this.insert({ /* ... */ } as any);
```

**With enforcement:**
```tsx
async upsertPreferences(
  userId: string, category: string,
  preferences: { email: boolean; in_app: boolean; sms: boolean }
): Promise<PreferencesRow> {
```

Same model. Same prompt. The difference: one had context explaining project conventions injected at the right moment.

The agent without enforcement isn't broken — it's doing the reasonable thing for a generic TypeScript codebase. It just doesn't know your codebase's rules. The fix isn't a smarter model. It's getting the right context to the agent at the right time, reliably, on every edit.

## The Architecture

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

Three tiers because single-file manifests don't scale. Research measured 29% reduction in runtime and 17% reduction in tokens when context is structured as hot/cold memory. Runtime enforcement pushes that to 92% compliance vs 40% with documentation alone.

There's also a positional attention argument. LLMs attend strongly to the beginning and end of their context window — the "lost-in-the-middle" effect. `AGENTS.md` loads at session start and gradually sinks into the low-attention middle zone as conversation accumulates. PreToolUse injection fires right before the edit, placing conventions at the recency-privileged end of the context window. Twenty lines in the right position outperform two hundred lines at the wrong time.

## Tier 1: Hot Memory (AGENTS.md)

~120-180 lines, loaded every session. This is the layer map, the dependency rules, the import alias table, the routing table pointing to domain docs, and a summary of what the enforcement hooks do.

Key discipline: AGENTS.md is universal context regardless of task. Domain-specific detail doesn't belong here — that's what cold memory is for. Every line that doesn't apply universally is a line that dilutes attention on lines that do.

What goes in AGENTS.md:
- Layer map with one-line descriptions
- Dependency rules (what can import what, explicit NEVER list)
- Import aliases and when to use them
- Routing table: "editing billing files? → `docs/domain/billing.md`"
- Enforcement summary: what the hooks do, how to interpret violations

What stays out:
- Business domain conventions (those go in leaf docs)
- Implementation details the agent can find by reading the code
- Standard patterns that any experienced dev would reach for anyway

## Tier 2: Cold Memory (Leaf Docs)

Docs organized along two axes: **layer** (where code lives architecturally) and **domain** (what business problem it solves).

```
docs/
  app/                    # Framework routing layer (Next.js, Remix, etc.)
  frontend/               # Client/UI layer
  server/                 # Backend layer
  shared/                 # Cross-layer utilities + types
  domain/                 # Business domains (cross-layer)
    billing.md
    orders.md
    inventory.md
  auth/                   # Auth (cross-layer, own axis)
  cross-cutting/          # Logging, error handling, enforcement
  testing/
```

A file like `src/server/services/inventory/inventory-repo.ts` belongs to both the **server/repositories** layer and the **inventory** domain. Layer docs cover structural conventions (how repos work, query builder patterns, single-table rule). Domain docs cover business conventions (deletion cascades, computed fields, cross-domain side effects).

### Leaf Doc Format

Each leaf doc has two sections:

```markdown
# Inventory Domain

Last verified: 2026-02-27

## Inject

Safe export pattern — the barrel (`index.ts`) omits `insert`, `update`, `remove`
from the repo export. Direct repo writes bypass orchestration (notifications,
cache invalidation, dependent cleanup). All mutations go through service-level
functions.

Deletion cascades across domains — `deleteItem()` archives all related pricing
records, removes the item from every referencing bundle, then deletes the record.
Miss a step and you get orphaned data.

Canonical examples:
- Safe export: `src/server/services/inventory/index.ts:35-36`
- Deletion cascade: `src/server/services/inventory/index.ts:272-295`

## Reference

[Full architecture, all the detail — not auto-injected]
```

The `## Inject` section is auto-injected (20-40 lines, hard limit 50). `## Reference` has no limit. The enforcer extracts only the inject section on each hook call.

### The Discoverability Filter

Before including anything in `## Inject`, ask: **can the agent figure this out by reading the code?** If yes, omit it.

Include: silent failures, cross-domain side effects, state machine traps, computed-not-stored fields, deletion cascades, non-obvious required helpers, canonical example paths with line numbers.

Exclude: what functions do, tech stack descriptions, standard patterns, anything discoverable from imports or directory structure.

This isn't just token efficiency — every line in an inject section signals something confusing enough to trip an agent. Probably confusing enough to trip a human too. When you fix the code to make it obvious, remove the instruction. Goal: leaf docs should shrink over time.

## Tier 3: Runtime Enforcement (Hooks)

This is where "usually follows conventions" becomes "always follows conventions." The gap between those two is where production systems fail.

### The Pipeline Architecture

The PreToolUse hook is a middleware pipeline — same pattern as HTTP middleware (auth, rate-limit, logging):

```
inject-context.mjs          ← orchestrator entry point
scripts/hooks/
  base.mjs                  ← buildContext() + runPipeline()
  inject-structure-context.mjs  ← structureCheck() middleware
  inject-code-context.mjs       ← codeContext() middleware
```

The orchestrator:

```js
// inject-context.mjs
import { buildContext, runPipeline } from './hooks/base.mjs';
import { structureCheck } from './hooks/inject-structure-context.mjs';
import { codeContext } from './hooks/inject-code-context.mjs';

const PIPELINE = [
  structureCheck(),   // blocks bad paths, injects placement context
  codeContext(),      // injects all matching domain docs
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

### Middleware 1: structureCheck()

Fires **only on `Write` to new files** in `src/`. Edits and overwrites pass through — the file is already placed.

Two checks:
1. **Blocked paths** — `[regex, guidance]` pairs for known-wrong locations: `src/utils/`, `src/components/`, layer-confused placements like `src/frontend/services/`, typo variants, standalone repos directory.
2. **New top-level directory** — any `src/<X>/` where `X` isn't `app`, `frontend`, `server`, or `shared` is blocked.

On a blocked path: exit 2 with a `BLOCKED:` message explaining the correct location. The file is never created — this is prevention, not cleanup.

On a valid new path: inject the `## Inject` section of `file-placement.md` so the agent sees the full directory map before it writes the file.

### Middleware 2: codeContext()

Walks the full ROUTES array and injects **every** matching doc — all-matches routing, not first-match-wins.

Order matters for output: general docs inject first, specific docs last. With recency bias, the most specific doc ends up closest to where the agent is working:

```
billing-repo.ts gets:
  1. service-patterns.md   (broad layer catchall)
  2. repositories.md       (layer-specific)
  3. billing.md            (domain-specific — injected last, closest to the edit)
```

The routing table is a simple array of `[pattern, docPath]` pairs in AGENTS.md. All-matches means domain + layer routes both fire. No more blind spots.

### PostToolUse: arch-validate.sh

Grep checks on modified files, exit 2 on violations:

```bash
#!/usr/bin/env bash

INPUT=$(cat)
ABS_FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
FILE="${ABS_FILE#"$PROJECT_ROOT/"}"

VIOLATIONS=""

# if [[ "$FILE" == src/some/path/* ]]; then
#   grep -q "bad_pattern" "$ABS_FILE" 2>/dev/null && \
#     VIOLATIONS+="What's wrong — how to fix\n"
# fi

if [ -n "$VIOLATIONS" ]; then
  echo -e "Arch violations in $FILE:\n$VIOLATIONS" >&2
  exit 2
fi
```

Production example: 15 blocking checks covering layer boundary imports, direct DB calls outside repos, `console.*`, `export default`, deprecated import aliases, deep imports bypassing barrels, cross-repo imports, wrong validation helper pattern, and file placement checks that redundantly cover what structureCheck already prevents.

Those last three (placement checks) are deliberate redundancy. PreToolUse catches bad paths at creation time. PostToolUse catches them if a file ends up in the wrong place via a Bash command that bypasses the Write hook. Defense in depth.

Exit 2 + stderr is the only PostToolUse feedback mechanism — there's no `additionalContext` support there (GitHub #18427).

### Wiring It Up

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

Use `$CLAUDE_PROJECT_DIR` — resolves correctly in subagents and worktrees. And **commit `.claude/settings.json` to git** — worktree agents check out from branch HEAD, so uncommitted hooks don't propagate.

## Testing

Three levels:

**Level 1: Script unit tests** — validate that inject-context routes correctly and arch-validate catches what it should. Run fake edits through both scripts and assert exit codes and output.

**Level 2: Blind injection exam** — launch fresh subagents across model tiers with this prompt:

> You are taking a blind exam. You have NO prior context about this codebase. Your ONLY source of domain knowledge is whatever gets injected via hooks when you edit files. For each section, edit the specified file, then answer the questions using ONLY the injected context. If the injection didn't cover a question, write "NOT IN INJECTION."

Pick 3-5 domains, 2 questions per domain, pre-verify every answer lives in the inject section. Launch one subagent per model tier in parallel — Opus, Sonnet, Haiku. This tests whether injection actually reaches the agent and is usable, not just whether the routing logic is correct.

**Level 3: Convention scoring on real edits** — grep-based scorer that checks actual source files after agents edit them. Domain-aware: different checks apply to schemas vs services vs repos vs views vs shared files.

**Context decay test:** 15 sequential edits across schemas, services, hooks, views, repos, and shared domain files. Each task tempts a specific violation. Our results: both Haiku and Sonnet scored 108/108 — zero decay. Compliance at file #15 was identical to file #1.

| Model      | Total tokens | Tool uses | Wall time | Tokens/file |
|------------|--------------|-----------|-----------|-------------|
| Haiku 4.5  | 136k         | 41        | 2m 37s    | ~9k         |
| Sonnet 4.6 | 72k          | 40        | 3m 23s    | ~4.8k       |

## Gotchas

**1. Absolute path mismatch (silent total failure)**

Claude Code sends `/Users/.../src/server/...` but routes match `^src/server/...`. Without stripping the project root, zero routes match. This silently disabled all enforcement until caught.

Both scripts must strip `$CLAUDE_PROJECT_DIR`:

```js
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

**2. Worktree hook propagation**

`.claude/settings.json` must be committed. `git worktree add` checks out from branch HEAD. No commit = no hooks in worktree = silent enforcement bypass.

**3. Dedup cache breaks parallel subagents**

Subagents share a session ID. A per-session dedup cache means only the first agent to edit a domain gets injection. Fix: no cache. 20-40 lines per injection is trivial token cost.

**4. All-matches routing resolves the priority blind spot**

Earlier versions used first-match-wins routing. A domain repo file would match the domain doc but never reach `repositories.md`. The fix was to migrate to all-matches routing — walk the full ROUTES array and inject every matching doc. A domain repo file now gets service-patterns + repositories + the domain doc in a single context block.

## The Results

Two features, two A/B runs, Haiku with and without enforcement:

| Feature | Without | With | Violations prevented |
|---------|---------|------|---------------------|
| Preferences API | 7/10 | 10/10 | Wrong validation helper, generic schema name, `any` params |
| Comparison util | 7.5/10 | 10/10 | `any` in types (x1), `any` in domain utils (x3) |
| **Average** | **7.25/10** | **10/10** | **7 violations** |

Three categories of mistakes:

| Category | Example | Caught by | Success rate |
|----------|---------|-----------|--------------|
| **Structural** | `console.log`, `export default`, cross-layer imports | PostToolUse grep → exit 2 | 100% — always self-corrects |
| **Pattern** | Wrong validation helper, `any` instead of `unknown` | PreToolUse injection | ~95% with injection (up from ~50% without) |
| **Judgment** | Error handling strategy, wrong abstraction level | Model capability only | ~70% — model-limited |

The enforcement system handles structural and pattern violations almost perfectly. Judgment calls remain model-limited — that's a different problem.

## This Is a Ratchet, Not a Cleanup Tool

One important framing: this system prevents backsliding on conventions that already exist. It doesn't create conventions. It's only useful if you have established architecture layers, documented dependency rules, and code patterns decided before enforcement can reference them.

Low existing violation counts matter too. Adding a blocking grep check on a pattern that already has 150 instances in your codebase will block every edit. Run `grep -rl 'pattern' src/ | wc -l` before adding any check. Only add when existing hits are 0-2.

The goal isn't to build the enforcement system first. The goal is to document what you already know your architecture should look like, then make the enforcement system the mechanical expression of those decisions. If your leaf docs are growing over time instead of shrinking, that's a signal your code has hidden complexity worth addressing at the source.

Get the conventions right. Then automate their enforcement. In that order.
