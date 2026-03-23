# Writing Guide

Last verified: 2026-03-21

## Inject

Article quality checklist. Run through this before publishing.

Opening: Does the first paragraph give the reader a reason to keep reading?
Don't open with definitions or background. Open with the problem, a story, or a claim.

Structure: Does every section earn its place? If you removed a section, would the
article lose something? If not, cut it.

Evidence: Every claim should be backed by either personal experience, data, or a
cited source. "Research shows" without a citation is worse than no claim at all.

Voice: Read it out loud. If a sentence sounds like it's performing instead of
communicating, rewrite it. If it sounds like AI wrote it, it probably needs your voice.

Code blocks: Are they minimal? Show only what's needed to make the point. A 50-line
code block where 10 lines matter is a 40-line tax on the reader.

Sources: Numbered inline references [1] with a Sources section at the bottom.
Format: `[N] Author/Publication // Description.<br>URL`
Use `//` as separator, not em dashes.

No em dashes (`—`) anywhere. Use commas, periods, colons, or parentheses.

## Reference

### Article structure that works for your content

Based on the articles written so far, this structure resonates:

1. **The problem** (from experience, not theory)
2. **The discovery** (what changed your thinking)
3. **The solution** (what you built or propose)
4. **What it looks like** (concrete example, code, diagrams)
5. **What doesn't work yet** (honest limitations)
6. **Sources** (numbered, linked)

The "what doesn't work yet" section is your differentiator. Most people skip it.
You include it. Keep doing that.

### Tags convention
Use lowercase, hyphenated tags. Keep the total set small and reusable:
- Technical topics: `ai`, `agents`, `claude-code`, `typescript`, `nextjs`, `architecture`
- Meta topics: `engineering`, `tooling`, `dx`
- Don't create one-off tags. If a tag won't be used on at least 2 posts, don't add it.

### Slug convention
Slugs auto-generate from filename. Use descriptive, URL-friendly filenames:
- Good: `agent-convention-enforcement.md` → `/blog/posts/agent-convention-enforcement`
- Bad: `article-1.md`, `draft-new-post.md`, `untitled.md`
