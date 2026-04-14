---
author: Andrew
pubDatetime: 2026-04-12T08:00:00Z
title: "Documentation-Driven Migration: A Strategy for AI-Assisted Codebase Restructuring"
featured: true
draft: false
tags:
  - ai
  - agents
  - engineering
  - architecture
  - refactoring
description: >
  How I used Claude to refactor a 170k-line Next.js codebase in two weeks. The doc-driven
  strategy, ESLint enforcement, and what I'd change next time.
---

How I used Claude to refactor a 170k-line Next.js codebase in two weeks. The doc-driven strategy, ESLint enforcement, and what I'd change next time.

---

## The Problem

We had a production Next.js app with 95 API routes and 210+ components scattered across a flat directory structure. It worked. It shipped. And every week it got harder to change.

I've been through this before. At a previous startup, we burned three months migrating a Next.js monolith to a separate Express API and Vite frontend. Would have been simple if we'd just moved the code. But the team decided to refactor _as_ we re-architected. "We're here already, so may as well fix it" turned into ballooning scope. Five engineers, three months, on a codebase half the size. It was a nightmare.

I'd been thinking about Joel Spolsky's ["Things You Should Never Do, Part I"](https://www.joelonsoftware.com/2000/04/06/things-you-should-never-do-part-i/) ever since reading it months prior. His argument: Netscape's rewrite was the single worst strategic mistake a software company can make. The code looked ugly, but it worked. Every ugly line was a bug found and fixed. Throwing it away meant throwing away years of knowledge.

Most migration guides will tell you to apply conventions first: get the code clean, then move it. There's a saying in chess: you should rarely violate the rules of positional play, but one of those times is when your opponent is already violating them. Applying conventions to thousands of lines of messy code as a _first_ step is an unequivocal nightmare. Instead, move the code where it belongs, organize it, _then_ apply conventions to the clean pieces.

So that's what I did. I had the authority to plan it my way, and I used Claude to take a 170k-line Next.js codebase from a flat directory with no layer boundaries to a four-layer architecture with enforced dependency direction, ESLint-backed conventions, and a repository pattern. 

---

## The Approach: Two Phases

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Phase 1: THE DOC SUITE                                                 │
│  Write the target architecture, conventions, move sequence,             │
│  per-file rulebook, and security audit BEFORE touching code.            │
│  7 documents. This IS the migration.                                    │
├─────────────────────────────────────────────────────────────────────────┤
│  Phase 2: THE MOVE SEQUENCE                                             │
│  Decompose the refactor into 10-20 atomic moves, each with             │
│  clear entry/exit criteria. Tag each as Mechanical or Judgment.         │
│  Every intermediate state must build. Grep gates verify completion.     │
└─────────────────────────────────────────────────────────────────────────┘
```

The core idea [[1]](#source-1): **the documents are not preparation for the migration. They are the migration.** The code changes are a mechanical consequence of sufficiently precise documentation.

---

## Phase 1: The Doc Suite

Before we moved a single file, we wrote seven documents that together formed a complete specification any agent could execute against.

I'd joined the team three weeks prior. I knew TypeScript and Next.js, but not this codebase. Writing these docs in a week was only possible because AI did the research. No human can hold 170k lines of context in their head at once. AI can. It loads the codebase into memory and immediately sees every connection, every dependency chain, every file that imports from somewhere it shouldn't. Weeks of manual tracing compressed into hours.

| Document                   | Audience     | Purpose                                                                                          |
| -------------------------- | ------------ | ------------------------------------------------------------------------------------------------ |
| **Architecture Overview**  | Humans + AI  | As-is analysis, top problems, target structure, migration summary, security audit scope           |
| **Conventions**            | Humans + AI  | The authoritative source for naming, imports, patterns, error handling, testing, logging          |
| **Implementation Guide**   | AI (primarily) | Step-by-step instructions for each move with code examples, risks, rollback procedures         |
| **Target Structure**       | AI           | Complete file inventory of the target state. Every file, every directory, annotated               |
| **Per-File Rulebook**      | AI           | Decision tree: given any file, where does it go? What transformations apply?                     |
| **Security Audit**         | Humans       | Known vulnerabilities discovered during analysis, fix timing, effort estimates                    |
| **LLM-Optimized Reference** | AI          | Dense, compressed version of all docs. Fits in a single context window                           |

### Document 1: Architecture Overview

The ADR [[3]](#source-3) for the entire refactor:

**As-Is Architecture:** tree diagram of the current structure with key stats.

```
tenkara-platform/                         # No src/ wrapper
  app/                                    # Next.js 14 App Router
    api/                                  # ~94 REST route handlers
  components/                             # ~210 component files, 18 subdirs
  lib/
    services/                             # 20 service files (business logic + DB mixed)
    types/                                # Domain interfaces
    hooks/                                # 11 client hooks
    context/                              # 6 React context providers
    utils/                                # 42 utility files (kitchen sink)
    supabase/                             # DB client, types, config
```

**Top Architectural Problems:** specific, with evidence. "8 files in `lib/utils/` import from `components/materials/quotes/types.ts`, inverting the dependency graph." Specific enough that an agent can verify whether a move addresses it.

**Target Architecture:** four layers with strict dependency direction:

```
src/
  app/          # ROUTING ONLY. Thin page shells, layouts, API route handlers.
  frontend/     # ALL CLIENT CODE. Components, hooks, context. Never imports server/.
  server/       # ALL SERVER CODE. DB, services, integrations. Never imports frontend/.
  shared/       # LEAF NODE. Types, pure utils, domain logic. No I/O.

Dependency direction:
  app → server / frontend → shared
  (server and frontend NEVER import from each other)
  (shared imports NOTHING outside itself)
```

**Migration Strategy Summary:** a table of all moves with type tags, one-line descriptions, and scope estimates.

### Document 2: Conventions

The authoritative source for how code should be written in the target architecture. This turned out to be the document agents referenced most frequently. It covered file placement rules, naming conventions, import rules with concrete ALLOWED and FORBIDDEN examples, API response shapes, route handler patterns, service/repository patterns, testing conventions, and logging rules.

The critical part: we encoded the layer boundary rules directly into ESLint. Frontend can't import from server. Shared can't import from server or frontend. Services can't call `supabase.from()` directly (must go through a `-repo.ts` file). Routes can't deep-import service internals (must use barrel exports). Legacy import paths (`@/lib/*`, `@/components/*`) are errors everywhere.

This meant the conventions doc were backed by tooling that would fail the build if an agent violated it.

### Document 3: Implementation Guide

The playbook for each move, primarily for AI agents. Each move got:

- **What:** one paragraph describing the transformation
- **Steps:** numbered, specific instructions. "Move these 6 files from X to Y. Update all importers. Run build."
- **Risks:** what could go wrong
- **Verification:** the exact commands to confirm success (`pnpm run build && pnpm run type-check && pnpm run test`)
- **Grep gates:** move-specific completion criteria as executable assertions (more on this in [Phase 2](#phase-2-the-move-sequence))
- **Rollback:** how to undo if it breaks

Here's a trimmed example of what one move entry looked like:

> **Move 3a: Pure type files -> `shared/types/` (M)**
>
> _Move all type-only files (no runtime values, erased at compile time) to their final location first. Types are imported by every other layer, so moving them early means all subsequent moves write their final-form import paths from day one._
>
> **Steps:**
> 1. Move the 6 pure-type files from `lib/types/` to `shared/types/` (same filenames)
> 2. Move `app/types/email.ts` to `shared/types/email.ts`
> 3. Move component-level type files (`components/settings/types.ts`, etc.) to `shared/types/{domain}.ts`
> 4. Create barrel exports (`index.ts`) for each subdirectory and root `shared/types/`
> 5. Update all imports (`@/lib/types/*` -> `@/shared/types/*`, `@/components/*/types` -> `@/shared/types/*`)
> 6. Delete empty source files
> 7. Run verification
>
> **Risks:** Some "shared" types are actually only used by one service. Leave those in place. Only move types imported by 2+ modules.
>
> **Verification:** `pnpm run build && pnpm run type-check && pnpm run test`
>
> **Grep gate:**
> ```bash
> # No type imports from old locations
> ! grep -r "from.*lib/types" src/ --include="*.ts" --include="*.tsx"
> # No database calls in shared types (layer violation)
> ! grep -r "supabase\|prisma\|\.from(" src/shared/types/ --include="*.ts"
> # No service imports in shared types (dependency direction violation)
> ! grep -r "from.*services/" src/shared/types/ --include="*.ts"
> # No component imports in shared types (layer violation)
> ! grep -r "from.*components/" src/shared/types/ --include="*.ts"
> # Barrel export exists
> test -f src/shared/types/index.ts
> ```
>
> **Rollback:** `git checkout HEAD -- src/lib/types src/components src/shared/types`

`(M)` means mechanical: file moves and import rewrites, no design decisions. `(J)` means judgment: requires domain knowledge (like splitting a 2,000-line service). Mechanical moves run with high confidence. Judgment moves need a human in the loop.

The grep gates were added after the fact when we realized a green build wasn't catching layer violations. A build will happily compile a database call in a shared type file. Grep gates catch what the compiler won't: violations that are syntactically valid but architecturally wrong. Next time, they'd be in from day one.

Every move is self-contained. If a move requires context from another move, it's scoped wrong.

We made every move's exit criterion a **green build.** The build breaks mid-move as files are in transit. That's expected. But no commit gets made until the build is green. Because the ESLint rules encode layer boundaries as build errors, a green build doesn't just mean "it compiles." It means the architecture is intact. No frontend importing server code, no services calling the database directly, no legacy import paths sneaking through. That's what makes moves atomic and independently revertible.

### Document 4: Target Structure

A complete file inventory of the target state. Every file path, annotated with what it does and where it came from. Without it, agents made judgment calls about where files should go. With it, every placement was deterministic. Here's a sample:

```
src/shared/
  types/
    materials.ts                  # From lib/types/materials.ts (Move 3a)
    formulas.ts                   # From lib/types/formulas.ts (Move 3a)
    orders.ts                     # From lib/types/orders.ts (Move 3a)
    suppliers.ts                  # From lib/types/suppliers.ts + components/materials/quotes/types.ts (Move 3b)
    shipping.ts                   # From lib/types/shipping.ts (Move 3a)
    email.ts                      # From app/types/email.ts (Move 3a)
    settings.ts                   # From components/settings/types.ts (Move 3a)
  lib/
    conversion-utils.ts           # From lib/utils/conversion-utils.ts (Move 4)
    date-utils.ts                 # From lib/utils/date-utils.ts (Move 4)
    upload-helpers.ts             # From lib/utils/upload-helpers.ts (Move 4)
    cn.ts                         # From utils.ts, Tailwind class merge (Move 4)
  domain/
    quotes/
      quote-calculations.ts       # From lib/utils/quote-calculations.ts (Move 5)
      quote-combination-utils.ts  # From lib/utils/quote-combination-utils.ts (Move 5)
    materials/
      material-utils.ts           # From lib/utils/material-utils.ts (Move 5)

src/server/services/materials/
  index.ts                        # Barrel export. Public API for materials domain. (Move 6b)
  materials-service.ts            # Core CRUD, validation, cascading deletes. Split from 2,127-line original (Move 6b)
  materials-repo.ts               # Extends BaseRepository<'materials'>. Extracted from service (Move 7)
  materials-quotes.ts             # Quote operations, split from materials-service.ts (Move 6b)
  materials-aggregation.ts        # Aggregation queries, split from materials-service.ts (Move 6b)
```

Every file had a deterministic destination. The agent never had to guess where something should end up.

### Document 5: Per-File Rulebook

A decision tree for any file in the codebase:

1. **Classify it:** is it a routing file, UI/client code, server code, or shared/pure code?
2. **Pick target path:** using the classification + target structure
3. **Apply transformations:** thin out route handlers, split large services, extract types
4. **Update importers:** every file that imports this one gets updated
5. **Run tests:** validate before moving on

The rulebook also encoded the move ordering: types first, then utilities, then services, then frontend. This is covered in more detail in [Phase 2](#phase-2-the-move-sequence).

### Document 6: Security Audit

A structural analysis of the codebase inevitably reveals security issues. Ours turned up 10, ranging from critical (RLS policies that were `USING (true)` on every table. any authenticated user could read any org's data) to low (missing security headers).

We documented these separately. Some could be fixed during the refactor; others needed their own project. The important thing was that the refactor didn't introduce new security issues and didn't silently depend on fixing the existing ones.

### Document 7: LLM-Optimized Reference

A compressed version of all the above in ~900 lines. Layer map, dependency rules, file placement, import patterns, naming, service patterns. We used this early on to give agents a single-file reference. In hindsight, context injection via CLAUDE.md rules or hooks is a better approach. The agent gets the relevant conventions at the point of need rather than a massive dump at session start that degrades as the context window fills.

---

## Phase 2: The Move Sequence

With the docs written, the refactor decomposed into a sequence of **atomic moves.** Each move was one logical transformation that took the codebase from one valid state to another. "Valid" meaning: builds, type-checks, tests pass.

### Move First, Split Second, Test Third

The common wisdom [[4]](#source-4) says write characterization tests before refactoring. That's impractical for most legacy codebases. Multi-thousand-line service files with circular dependencies and no docs on what the endpoint is even supposed to do? Writing unit tests for that monolith will take ages, and the conventional advice asks teams to dedicate months to an exercise most will never finish. [[5]](#source-5)

Spolsky's core insight applies here: the old code works. It's ugly, it's tangled, but every ugly line represents a bug that was found and fixed. So don't rewrite it. Move it where it's supposed to be first. Get the structure right with the code that already works. _Then_ functionalize, split up the logic, then write unit tests for the clean pieces. The tests are easy because the functions are small and focused. And you never threw away the knowledge baked into the original code.

### Our Move Sequence

Here's the actual sequence we used. Your codebase will obviously need a different set of moves, but the shape might be similar:

| Move    | Type | What                                                                                                    |
| ------- | ---- | ------------------------------------------------------------------------------------------------------- |
| 1       | M    | Create `src/` skeleton + path aliases. Config only, no file moves.                                      |
| 2       | M    | Pages + API routes + route groups. Move `app/` into `src/app/` with proper route grouping. ~120 files.  |
| 3a      | M    | Pure type files to `src/shared/types/`. Zero runtime risk. Types are erased at compile time.            |
| 3b      | J    | Mixed type files. Extract type declarations from files that also contain runtime values.                |
| 4       | M    | Pure utilities to `src/shared/lib/`. Leaf dependencies, no classification needed.                       |
| 5       | J    | Domain utilities to `src/shared/domain/`. Classify ~30 files by business domain. Circular deps break here. |
| 6a      | M    | Small services + auth + integrations. Mechanical moves to `src/server/`.                                |
| 6b-6e   | J    | Split 4 large service files (1,400-2,100 lines each) into domain directories with barrel exports.       |
| 7       | J    | Repository layer. Create `BaseRepository` abstraction. Extract repo into each service dir.              |
| 8       | J    | Extract large API routes. Inline logic moves to services. Routes become thin HTTP adapters.               |
| 9a-9c   | M    | Frontend: UI components, domain views, hooks, and context providers to `src/frontend/`.                 |
| 9d      | J    | Decompose bloated contexts (1,000+ line CartContext) into slim providers + focused hooks.                |
| 10      | M/J  | Cleanup + boundary enforcement. `server-only`/`client-only` guards, ESLint rules, delete stale files.   |

### The Ordering Logic

The sequence is a topological sort of the import graph: **leaf dependencies first, composite code last.** Types are imported by everything, so they move first. Pure utilities depend only on types, so they go second. Services third. Frontend last.

The circular dependencies that plagued the old codebase disappeared almost entirely once code landed in properly organized service files. The only thing that got hairy was when the agent drifted from the expected file structure, which is exactly the problem grep gates would have caught.

### The Dual-Alias Strategy

One implementation detail that saved us a lot of pain: during migration, both old and new import paths worked simultaneously. We used TypeScript path aliases:

```json
{
  "compilerOptions": {
    "paths": {
      "@/*": ["./*"],
      "@/server/*": ["./src/server/*"],
      "@/frontend/*": ["./src/frontend/*"],
      "@/shared/*": ["./src/shared/*"]
    }
  }
}
```

Unmigrated code kept using `@/lib/...` (resolving through the old `@/*` catch-all). Migrated code used `@/server/...`, `@/frontend/...`, `@/shared/...`. Both resolved simultaneously. At the end of migration, we flipped the catch-all and deleted the old paths.

This is basically the Strangler Fig pattern [[2]](#source-2) applied at the import level. Old paths gradually die as files move. New paths grow. At no point does the build break because of a path resolution failure.

### Grep Gates: Build-Green Is Not Enough

A green build tells you nothing broke. It doesn't tell you the move achieved its goal. The dual-alias strategy makes this especially dangerous. the build passes because old paths still resolve, even if files haven't actually moved yet. That's a false positive.

We learned (somewhat painfully) that every move needs **move-specific completion criteria as executable assertions.** We started calling these grep gates. bash scripts that run after each move and act as hard pass/fail checkpoints.

For example, after Move 3 (types to `src/shared/types/`):

```bash
#!/bin/bash
# gate-move-3.sh. Verify type files migrated to shared/types

FAIL=0

# FAIL if any type-only files remain in old location
if grep -rl "export \(type\|interface\)" lib/types/ 2>/dev/null | grep -q .; then
  echo "FAIL: Type-only files still in lib/types/"
  grep -rl "export \(type\|interface\)" lib/types/
  FAIL=1
fi

# FAIL if target directory doesn't have expected file count
COUNT=$(find src/shared/types -name "*.ts" 2>/dev/null | wc -l)
if [ "$COUNT" -lt 15 ]; then
  echo "FAIL: Expected >= 15 type files in src/shared/types/, found $COUNT"
  FAIL=1
fi

# FAIL if any file in shared/types imports from server or frontend
if grep -rl "@server/\|@frontend/" src/shared/types/ 2>/dev/null | grep -q .; then
  echo "FAIL: shared/types contains cross-layer imports"
  grep -rl "@server/\|@frontend/" src/shared/types/
  FAIL=1
fi

exit $FAIL
```

After Move 6 (services to `src/server/`):

```bash
#!/bin/bash
# gate-move-6.sh. Verify services migrated and layer boundaries hold

FAIL=0

# FAIL if service files remain in old location
if ls lib/services/*.ts 2>/dev/null | grep -q .; then
  echo "FAIL: Service files still in lib/services/"
  ls lib/services/*.ts
  FAIL=1
fi

# FAIL if any server file imports from frontend
if grep -rl "@frontend/" src/server/ 2>/dev/null | grep -q .; then
  echo "FAIL: Server files importing from frontend layer"
  grep -rl "@frontend/" src/server/
  FAIL=1
fi

# PASS check: barrel exports exist for each service domain
for dir in src/server/services/*/; do
  if [ ! -f "${dir}index.ts" ]; then
    echo "FAIL: Missing barrel export in $dir"
    FAIL=1
  fi
done

exit $FAIL
```

The agent runs the gate after each move. Red means "keep going." Green means "commit and move on."

---

## What We Learned

### The docs took as long as the code changes

The docs took just as much time as the code changes. We spent the better part of a week planning, strategizing, and writing. The following week was spent refining how much the agent got done with each move, running continuous passes rather than trying to nail everything on the first try. We used [ralph](https://github.com/snarktank/ralph), a Claude Code skill that runs a prompt on a recurring interval, to keep the agent working through the night. Wake up, review what it did, course-correct, loop again. Had we built the grep gates into the implementation guide from day one, the refinement cycles would have been shorter.

### Security audits are free during refactoring

Mapping the architecture for a refactor gives you the exact mental model needed for a security audit. The marginal cost of documenting security issues while you're already reading every route handler is nearly zero. We found critical RLS policy issues that had been silently present for months. If you're already doing the refactor, the security audit is basically free.

---

## What I'd Do Differently

The doc suite and move sequence worked. But the docs should have been infrastructure from the start. The Per-File Rulebook and grep gates should have been hooks that ran after every edit. The Conventions doc should have been leaf docs injected at edit time, not a monolith loaded at session start. We built all of this _after_ the migration for ongoing development. Next time, we'd set it up before Move 1. For the full system, see [Hook-Based Context Injection for AI Coding Agents](/posts/agent-convention-enforcement-system).

---

## Sources

<span id="source-1">[1]</span> Ziftci et al., ["Migrating Code At Scale With LLMs At Google"](https://arxiv.org/abs/2504.09691) (arXiv, April 2025). Google's finding that migration quality is bounded by specification quality. Their context is homogeneous transformations (32-bit to 64-bit), not architectural refactors, but the core principle holds.

<span id="source-2">[2]</span> Fowler, ["Strangler Fig Application"](https://martinfowler.com/bliki/StranglerFigApplication.html) (martinfowler.com). Incrementally replace system components while keeping production running.

<span id="source-3">[3]</span> Nygard, ["Architecture Decision Records"](https://tarf.co.uk/Reference/Architecture/adr/decision_record_template/). Short documents capturing architectural decisions and their context.

<span id="source-4">[4]</span> Feathers, _Working Effectively with Legacy Code_ (Prentice Hall, 2004). Defines legacy code as "code without tests." Advocates characterization tests before refactoring.

<span id="source-5">[5]</span> ScanMyCode.dev, ["Refactoring Legacy Code When There Are No Tests"](https://www.scanmycode.dev/blog/refactoring-techniques-legacy-code-without-tests) (March 2026); StackOverflow, ["Should you refactor when there are no tests?"](https://workplace.stackexchange.com/questions/198982/should-you-refactor-when-there-are-no-tests) (August 2024). Practitioners documenting the gap between textbook advice and real-world constraints.

<span id="source-6">[6]</span> Spolsky, ["Things You Should Never Do, Part I"](https://www.joelonsoftware.com/2000/04/06/things-you-should-never-do-part-i/) (Joel on Software, April 2000). Netscape's full rewrite as the canonical example of why you should never throw away working code.
