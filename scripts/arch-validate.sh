#!/usr/bin/env bash

INPUT=$(cat)
ABS_FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

# Strip project root for pattern matching
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
FILE="${ABS_FILE#"$PROJECT_ROOT/"}"

VIOLATIONS=""

# --- Blog post checks ---
if [[ "$FILE" == src/data/blog/*.md ]]; then
  # Block h1 in blog post body (frontmatter title is h1)
  # Skip frontmatter (between --- delimiters), then check for ^#
  if awk '/^---$/{f++; next} f>=2' "$ABS_FILE" 2>/dev/null | grep -qE '^# [^#]'; then
    VIOLATIONS+="Do not use h1 (#) in blog post body — the frontmatter title renders as h1. Use ## through ###### instead.\n"
  fi

  # Block <img> tags referencing src/assets (won't be optimized)
  if grep -qE '<img[^>]+src="(@/assets|\.\.\/.*assets)' "$ABS_FILE" 2>/dev/null; then
    VIOLATIONS+="Do not use <img> tags for images in src/assets/. Use markdown syntax: ![alt](@/assets/images/example.jpg)\n"
  fi

  # Check required frontmatter fields
  if ! head -30 "$ABS_FILE" | grep -q '^title:'; then
    VIOLATIONS+="Missing required frontmatter field: title\n"
  fi
  if ! head -30 "$ABS_FILE" | grep -q '^description:'; then
    VIOLATIONS+="Missing required frontmatter field: description\n"
  fi
  if ! head -30 "$ABS_FILE" | grep -q '^pubDatetime:'; then
    VIOLATIONS+="Missing required frontmatter field: pubDatetime\n"
  fi
fi

# --- Utility checks ---
if [[ "$FILE" == src/utils/*.ts || "$FILE" == src/utils/*.js ]]; then
  if grep -qE '^export default ' "$ABS_FILE" 2>/dev/null; then
    VIOLATIONS+="Use named exports in utility files, not export default.\n"
  fi
fi

# --- Structure checks (defense in depth) ---
if [[ "$FILE" == src/lib/* ]]; then
  VIOLATIONS+="Wrong directory: src/lib/ does not exist. Use src/utils/ for utilities.\n"
fi
if [[ "$FILE" == src/services/* ]]; then
  VIOLATIONS+="Wrong directory: src/services/ does not exist. This is a static blog — use src/utils/.\n"
fi
if [[ "$FILE" == src/api/* ]]; then
  VIOLATIONS+="Wrong directory: No API routes. This is a fully static Astro site.\n"
fi
if [[ "$FILE" == src/hooks/* ]]; then
  VIOLATIONS+="Wrong directory: src/hooks/ does not exist. This is Astro, not React.\n"
fi

if [ -n "$VIOLATIONS" ]; then
  echo -e "Arch violations in $FILE:\n$VIOLATIONS" >&2
  exit 2
fi

exit 0
