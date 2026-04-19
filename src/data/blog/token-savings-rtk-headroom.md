---
author: Andrew
pubDatetime: 2026-04-18T08:00:00Z
title: "Token Compression for Claude Code with RTK + Headroom"
slug: token-savings-rtk-headroom
featured: true
draft: false
tags:
  - ai
  - agents
  - claude-code
  - engineering
  - token-optimization
description: >
  RTK filters CLI command output before it enters the context window. Headroom compresses
  API context via a local proxy. Together they saved 1.5B tokens of CLI noise over a month
  on a production codebase. Setup guide and measured results included.
---

RTK filters CLI command output before it enters the context window. Headroom compresses API context via a local proxy. Together they saved 1.5B tokens of CLI noise over a month on a production codebase. Setup guide and measured results included.

---

## The Problem

Every CLI command an AI coding agent runs returns output that enters the context window as tokens. `git log` returns commit hashes, author emails, GPG signatures, merge metadata. `cat` returns entire files when the agent needs one function. `npm test` dumps thousands of lines when only the failures matter.

This output is designed for humans to scan, not for models to reason over. Every decorative header, alignment space, and repeated path prefix is a token consumed with no effect on the agent's next decision.

On a production TypeScript/Next.js codebase, I measured where tokens were going across 26,779 commands and 2,246 API requests over a month. Two compression layers, operating at different points in the pipeline, filtered 1.5 billion tokens of CLI noise and redundant context.

---

## Measured Results From a Month of Usage 

### Combined

| Metric | Value |
|---|---|
| Total tokens saved | 1,516,714,601 |
| RTK (command output filtering) | 1,327,700,000 |
| Headroom (session compression) | 189,014,601 |
| API requests observed | 2,246 |
| Commands filtered | 26,779 |
| Cost savings (Headroom-tracked) | $3,808 |

### RTK. Per-Command Breakdown

| Command | Count | Tokens Saved | Reduction |
|---|---|---|---|
| `read` (file reads) | 3,993 | 1,138.3M | 66.9% |
| `grep` (search) | 4,289 | 156.1M | 33.6% |
| `lint` (eslint) | 9 | 19.4M | 100.0% |
| `vitest` (tests) | 110 | 3.4M | 98.6% |
| `tsc` (type check) | 2 | 2.0M | 100.0% |
| `find` (file search) | 1,300 | 1.8M | 75.8% |
| `ls` (directory listing) | 1,873 | 479.7K | 66.8% |

The largest single source of savings is file reads. Agents read files constantly, and most of that content is irrelevant to the current task.

### Headroom. Per-Model Breakdown

| Model | Tokens Sent | Tokens Saved | Reduction | Requests |
|---|---|---|---|---|
| opus-4-6 | 139.7M | 158.2M | 53.1% | 1,253 |
| sonnet-4 | 20.2M | 29.1M | 59.1% | 781 |
| haiku-4-5 | 1.4M | 670.2K | 31.7% | 141 |
| opus-4-5 | 819.5K | 368.9K | 31.0% | 29 |
| sonnet-4-6 | 965.6K | 569.3K | 37.1% | 32 |

Prefix cache hit rate: 96%. This alone accounted for $355 in savings by avoiding redundant prompt processing.

---

## Mechanism 1: Command Output Filtering (RTK)

[RTK](https://github.com/rtk-ai/rtk) is a Rust binary that intercepts CLI commands and returns compressed output. It applies four strategies: smart filtering (removes boilerplate), grouping (aggregates similar items), truncation (keeps relevant context), and deduplication (collapses repeated lines).

It operates as a Claude Code PreToolUse hook. When the agent calls `git status`, the hook rewrites the command to `rtk git status` before execution. The compressed output enters the context window instead of the raw output. The agent receives the same information in fewer tokens.

```
Agent calls: git status
  ↓
PreToolUse hook fires
  ↓
Hook rewrites: rtk git status
  ↓
RTK runs git status, filters output
  ↓
Compressed output enters context (80% smaller)
```

The hook is a bash script registered in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "/path/to/rtk-rewrite.sh"
      }]
    }]
  }
}
```

The hook reads the tool input from stdin, extracts the command, passes it to `rtk rewrite`, and returns the rewritten command as `updatedInput`. Claude Code executes the rewritten command transparently.

Overhead is <10ms per command. The agent does not know RTK exists. It sees the same tool interface and receives semantically equivalent output.

---

## Mechanism 2: Session Compression (Headroom)

[Headroom](https://github.com/chopratejas/headroom) is a proxy that sits between the coding agent and the API provider. It compresses tool results and leverages prefix caching to reduce token consumption at the API level.

It operates as a Claude Code SessionStart hook. When a session begins, the hook starts a proxy on `localhost:8787` and sets `ANTHROPIC_BASE_URL` to route all API traffic through it.

```
Agent makes API request
  ↓
Request hits Headroom proxy (localhost:8787)
  ↓
Headroom compresses tool results in the request
  (JSON arrays: 83-90%, shell output: 85%, build logs: 94%)
  (Source code and grep results pass through untouched)
  ↓
Compressed request forwarded to Anthropic API
  ↓
Prefix caching reuses previously processed prompt prefixes
```

Compression is content-aware. JSON arrays and build logs compress heavily. Source code passes through unmodified. Headroom does not apply lossy compression to code because that would degrade the model's ability to reason about it.

### Prefix caching (Anthropic's, not Headroom's)

Prefix caching is an Anthropic API feature. When the beginning of your prompt matches a previous request, Anthropic serves the cached prefix at a 90% discount on input tokens. This happens at the API level regardless of whether Headroom is running.

Headroom's role is to *maximize cache hits*. When it compresses tool results, it leaves the system prompt and early conversation turns untouched so the prefix stays stable between requests. Without this, compression or compaction can change the prompt prefix and bust the cache. In my measurements, this prefix-aware strategy produced a 96% cache hit rate and $355 in Anthropic-side savings.

Headroom's [published benchmarks](https://github.com/chopratejas/headroom/blob/main/docs/content/docs/benchmarks.mdx) show negligible accuracy loss with high compression ratios across 250+ production instances. My overhead was higher than their reported median because coding sessions involve larger payloads than typical use cases.

---

## How They Compose

RTK and Headroom operate at different layers and are independent. Either can be used without the other.

```
┌──────────┐     ┌─────────────┐     ┌─────────┐     ┌──────────────┐     ┌──────────────┐
│  Agent   │────▶│  RTK hook   │────▶│  Bash   │────▶│   Headroom   │────▶│  Anthropic   │
│          │     │  (rewrite)  │     │ (runs)  │     │   (compress) │     │  API         │
│          │◀────│             │◀────│ filtered│     │              │     │              │
│  sees    │     │             │     │ output  │     │              │     │              │
│  small   │     │             │     │         │     │              │     │              │
│  output  │     │             │     │         │     │              │     │              │
└──────────┘     └─────────────┘     └─────────┘     └──────────────┘     └──────────────┘
  Layer:           PreToolUse           Shell            API proxy            Provider
  Savings:         60-90%                               16-59%
```

RTK reduces noise per command. Headroom compresses what remains before it hits the API. The savings are additive: RTK's filtered output is further compressed by Headroom's proxy.

---

## Configuration

### Automated setup

I wrote a Claude Code skill that detects, installs, and wires both tools. It handles platform detection, hook wiring, and the PATH fix automatically:

[`/token-savings` skill on GitHub](https://github.com/andrew-tenkara/CLAUDE-MD/tree/main/skills/token-savings)

Clone the repo anywhere on your machine, then symlink the skill into your Claude Code skills directory:

```bash
git clone https://github.com/andrew-tenkara/CLAUDE-MD.git ~/Projects/CLAUDE-MD
ln -sf ~/Projects/CLAUDE-MD/skills/token-savings ~/.claude/skills/token-savings
```

Run `/token-savings` in any Claude Code session. 

### Live monitoring

The skill also includes a TUI dashboard you can run in a separate terminal:

```bash
python3 ~/.claude/skills/token-savings/scripts/tui.py
```

![Token Savings TUI Dashboard](/images/token-savings-tui.png)

The dashboard shows RTK stats on the left (command count, per-command breakdown, efficiency bar) and Headroom stats on the bottom-left (compression rate, prefix cache hit rate, per-model breakdown, cost savings). The right pane is a live feed of recent API requests, color-coded by compression percentage. It reads directly from the Headroom log file, so it captures all requests across all agent sessions, not just the current one.

Requires `rich` (`pip install rich`). Auto-refreshes every 2 seconds. `Ctrl+C` to exit.

### Manual setup

If you prefer to set things up yourself:

**RTK:**
```bash
# Install
brew install rtk-ai/tap/rtk        # macOS
cargo install rtk-cli               # Linux / WSL

# Wire the hook
rtk init -g                         # creates ~/.claude/hooks/rtk-rewrite.sh
                                    # and registers it in settings.json

# Verify
rtk gain                            # should show savings after a few commands
```

**Headroom:**
```bash
# Install
pip install "headroom-ai[proxy]"

# Wire the hook (create ~/.claude/hooks/headroom-autostart.sh)
# The script should:
#   1. Check if proxy is running (curl localhost:8787/health)
#   2. If not, start: headroom proxy --port 8787 &
#   3. Set ANTHROPIC_BASE_URL=http://localhost:8787

# Register in ~/.claude/settings.json as a SessionStart hook

# Verify
curl http://localhost:8787/health    # should return {"status": "healthy"}
```

---

## Gotchas

### `rtk init -g` overwrites your PATH fix

Running `rtk init -g` regenerates `rtk-rewrite.sh` from scratch, blowing away any manual PATH edits. RTK also integrity-checks this file with SHA-256 and refuses to run if it's been modified, so you can't patch it directly. The durable fix is a wrapper script that RTK doesn't manage:

```bash
# ~/.claude/hooks/rtk-wrapper.sh — NOT managed by rtk, survives rtk init -g
#!/usr/bin/env bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.cargo/bin:$PATH"

OUTPUT=$(bash "$(dirname "$0")/rtk-rewrite.sh" "$@")
EXIT_CODE=$?

if [ -z "$OUTPUT" ] || [ $EXIT_CODE -ne 0 ]; then
  exit $EXIT_CODE
fi

# Strip permissionDecision (see "permissionDecision auto-allow" gotcha below)
echo "$OUTPUT" | jq '
  if .hookSpecificOutput then
    .hookSpecificOutput |= del(.permissionDecision, .permissionDecisionReason)
  else
    .
  end
' 2>/dev/null || echo "$OUTPUT"

exit $EXIT_CODE
```

Point the hook in `settings.json` at `bash ~/.claude/hooks/rtk-wrapper.sh` (note the `bash` prefix — see the provenance gotcha below). RTK can regenerate its script freely without breaking any fix.

### RTK hook silently fails without PATH fix

Claude Code runs hooks in a minimal PATH (`/usr/bin:/bin:/usr/sbin:/sbin`). If RTK is installed via Homebrew (`/opt/homebrew/bin/`) or cargo (`~/.cargo/bin/`), the hook's `command -v rtk` check fails silently, exits 0, and every command passes through unfiltered. No errors. No warnings. You just don't get savings.

This is [documented as GitHub issue #685](https://github.com/rtk-ai/rtk/issues/685) on RTK's repo. The fix is one line at the top of the hook script:

```bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.cargo/bin:$PATH"
```

RTK's `rtk init -g` does not add this line as of v0.37.0. You need to add it manually. My `/token-savings` skill checks for this automatically.

### RTK name collision

Two different packages are named "rtk": Rust Token Killer ([rtk-ai/rtk](https://github.com/rtk-ai/rtk)) and Rust Type Kit (reachingforthejack/rtk). If `rtk gain` returns "command not found" but `rtk --version` works, you have the wrong package.

### RTK hook must be last in PreToolUse array

If you have other PreToolUse hooks with `matcher: "Bash"` (e.g. context injection, wakatime), RTK's hook must be the last entry in the array. If another hook runs first and doesn't pass stdin through correctly, RTK's hook never receives the tool input. I discovered this running multiple PreToolUse hooks for context injection alongside RTK.

### Hooks don't fire for Agent tool teammates

PreToolUse hooks (including RTK's) do not fire for teammates spawned via the Agent tool ([Claude Code #42385](https://github.com/anthropics/claude-code/issues/42385)). Only the main session and standard subagents get hook-based filtering. If you're running multi-agent setups, teammates won't benefit from RTK unless each has its own session.

### Some requests show higher token counts after Headroom

You may notice `router:noop` requests where the "after" count is slightly higher than "before" (e.g. 136.9K before, 137.4K after). When Headroom's content router determines a request doesn't benefit from compression, it passes through. I observed a consistent ~200-500 token increase on passthrough requests, likely proxy metadata overhead. On a 137K request, that's <0.4%. I have not found documentation for this behavior in Headroom's repo; this is based on my own observations.

### Headroom falls back silently

If Headroom fails to start (port conflict, crash, missing dependency), the SessionStart hook exits 0 and Claude Code connects directly to Anthropic. Sessions work fine, you just don't get compression. Verify with `curl -sf http://localhost:8787/health`.

### Headroom port conflicts

If something else is already running on port 8787, Headroom will fail to start. Check with `lsof -i :8787`. Use `headroom proxy --port 8788` and update `ANTHROPIC_BASE_URL` accordingly if you need a different port.

### Hook changes require a new session

Claude Code loads hooks at session start. If you fix the PATH issue or add a new hook, existing sessions won't pick it up. Only new sessions get the fix. Don't restart running agents just for this.

### Corporate proxy conflicts with ANTHROPIC_BASE_URL

If your environment sets `HTTP_PROXY` or `HTTPS_PROXY`, Claude Code may route Headroom's local traffic through the corporate proxy instead of connecting directly to `localhost:8787`. Set `NO_PROXY=localhost,127.0.0.1` in your environment. Note that some Claude Code versions have [a bug where NO_PROXY is ignored](https://github.com/anthropics/claude-code/issues/39862); the workaround is to unset proxy vars before launching: `HTTP_PROXY="" HTTPS_PROXY="" claude`.

### jq is required for the RTK hook

The RTK hook script depends on `jq` for JSON parsing. If `jq` is not installed, the hook silently exits. Install with `brew install jq` (macOS) or `apt install jq` (Linux).

### `permissionDecision: "allow"` silently kills savings

RTK's hook emits `"permissionDecision": "allow"` alongside `updatedInput` in its JSON output. This auto-bypasses Claude Code's permission system for every rewritten command — a security concern ([rtk-ai/rtk#260](https://github.com/rtk-ai/rtk/issues/260), [#1155](https://github.com/rtk-ai/rtk/issues/1155)), but more importantly a **silent savings killer**.

When `skipDangerousModePermissionPrompt` or `skipAutoPermissionPrompt` is `true` in `settings.json`, Claude Code can skip the permission handling path entirely. When it does, `updatedInput` that came bundled with `permissionDecision` gets **discarded**. The original uncompressed command runs instead — no errors, no warnings, full token output hits the context window.

You can't fix this in `rtk-rewrite.sh` because RTK integrity-checks it (SHA-256) and refuses to run if modified. The fix lives in the wrapper script: pipe the hook output through `jq` to delete `permissionDecision` and `permissionDecisionReason`, keeping only `updatedInput`. Claude Code then processes the rewrite through its normal permission flow. See the updated wrapper script in the `rtk init -g` gotcha above.

### macOS Sequoia `com.apple.provenance` causes intermittent hook failures

macOS Sequoia tags files with a `com.apple.provenance` extended attribute that can't be removed — Sequoia reapplies it at the directory level. When Claude Code invokes hooks via `/bin/sh`, this attribute intermittently causes "Permission denied" errors, even with 755 permissions.

In Claude Code, this shows up as:

```
⎿  PreToolUse:Bash hook error
⎿  Failed with non-blocking status code: /bin/sh: /Users/you/.claude/hooks/rtk-wrapper.sh: Permission denied
```

The exit code from a permission denied crash is non-zero and non-2. Per Claude Code's exit code contract, that's a "non-blocking error" — the command runs **unmodified**. So `cat` instead of `rtk read`, `grep` instead of `rtk grep`, full uncompressed output.

**Important:** If you're seeing these permission denied errors, you're very likely also being hit by the `permissionDecision` gotcha above at the same time. The provenance errors are the visible symptom — they show up in Claude's output. But the `permissionDecision` leak is completely silent: commands run uncompressed with no error, no warning. Both cause lost savings independently. The permission denied errors are the canary — if you're seeing them, check whether the `permissionDecision` strip is also missing from your wrapper.

**Fix:** Prefix the hook command in `settings.json` with `bash` so the shell reads the file as data instead of exec'ing it:

```json
"command": "bash /Users/you/.claude/hooks/rtk-wrapper.sh"
```

This bypasses the exec permission check entirely. Apply the same prefix to any other hooks (Headroom, custom validators, etc.).

---

## Tools Not Yet Evaluated

The following projects address tackling token saving with different approaches, I've yet to test these but intend to in the future. If they prove beneficial, I'll be sure to update this article! 

- **[Tamp](https://github.com/sliday/tamp)**: JS-based token compression proxy with configurable pipeline stages (minify, dedup, diff, prune). Claims 52.6% savings. `npx @sliday/tamp`. No Python dependency.
- **[Kompact](https://github.com/npow/kompact)**: Python proxy using TF-IDF based compression. Claims 40-70% savings. Different algorithmic approach than Headroom's ML compression.
- **[ClaudeSlim](https://github.com/apolloraines/claudeslim)**: Python proxy targeting 60-85% compression via message-level compression. Early stage.

---

## References

1. rtk-ai/rtk. https://github.com/rtk-ai/rtk (28.6K stars, Apache 2.0)
2. chopratejas/headroom. https://github.com/chopratejas/headroom (1.4K stars, Apache 2.0)
3. Headroom production benchmarks. https://github.com/chopratejas/headroom/blob/main/docs/content/docs/benchmarks.mdx
4. Menon Lab, "rtk: A Rust CLI Proxy That Cuts AI Agent Token Usage 60-90%". https://themenonlab.blog/blog/rtk-cli-proxy-token-reduction-ai-agents
5. Estrada, "RTK: The Rust Binary That Slashed My Claude Code Token Usage by 70%". https://codestz.dev/experiments/rtk-rust-token-killer
6. Morph, "Claude Code Context Window: Limits, Compaction & Management Guide". https://www.morphllm.com/claude-code-context-window
