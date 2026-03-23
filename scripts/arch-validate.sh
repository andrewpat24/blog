#!/usr/bin/env bash
# scripts/arch-validate.sh
#
# PostToolUse hook -- fires after every Edit or Write.
# Targeted grep checks on the modified file.
#
# Exit codes:
#   0 = clean
#   2 = blocking violation

INPUT=$(cat)
ABS_FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

# Strip project root for pattern matching
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
FILE="${ABS_FILE#"$PROJECT_ROOT/"}"

VIOLATIONS=""
WARNINGS=""

# -----------------------------------------------------------------------
# Blog post checks
# -----------------------------------------------------------------------
if [[ "$FILE" == src/data/blog/*.md ]]; then
  # Block h1 in blog post body (frontmatter title is h1)
  # Skip frontmatter (between --- delimiters) and fenced code blocks, then check for ^#
  if awk '/^---$/{f++; next} f<2{next} /^```/{code=!code; next} code{next} 1' "$ABS_FILE" 2>/dev/null | grep -qE '^# [^#]'; then
    VIOLATIONS+="Do not use h1 (#) in blog post body. The frontmatter title renders as h1. Use ## through ###### instead.\n"
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

  # Block em dashes in blog post prose (use commas, periods, colons, parentheses instead)
  # Skip frontmatter, fenced code blocks, and table rows (ASCII diagrams use dashes)
  if awk '/^---$/{f++; next} f<2{next} /^```/{code=!code; next} code{next} /^\|/{next} /^[│├└┌┐┘┤┬┴─]/{next} 1' "$ABS_FILE" 2>/dev/null | grep -qF '—'; then
    VIOLATIONS+="Em dash detected in post body. Use commas, periods, colons, or parentheses instead.\n"
  fi

  # Check date format is ISO 8601 (not slash-separated or informal)
  if head -30 "$ABS_FILE" | grep -q '^pubDatetime:' && ! head -30 "$ABS_FILE" | grep -qE '^pubDatetime:\s*[0-9]{4}-[0-9]{2}-[0-9]{2}'; then
    VIOLATIONS+="pubDatetime must be ISO 8601 format: 2026-03-21T08:00:00Z\n"
  fi

  # Warn on description over 155 characters (SEO)
  DESC=$(head -30 "$ABS_FILE" | grep -A5 '^description:' | sed 's/^description:\s*//' | tr -d '\n' | sed 's/^>\s*//' | sed 's/^\s*//')
  if [ ${#DESC} -gt 155 ] 2>/dev/null; then
    WARNINGS+="Description is ${#DESC} chars (aim for under 155 for SEO).\n"
  fi
fi

# -----------------------------------------------------------------------
# Utility checks
# -----------------------------------------------------------------------
if [[ "$FILE" == src/utils/*.ts || "$FILE" == src/utils/*.js ]]; then
  if grep -qE '^export default ' "$ABS_FILE" 2>/dev/null; then
    VIOLATIONS+="Use named exports in utility files, not export default.\n"
  fi
fi

# -----------------------------------------------------------------------
# Component checks
# -----------------------------------------------------------------------
if [[ "$FILE" == src/components/*.astro ]]; then
  # Block React/Vue imports in Astro components (unless explicitly adding integration)
  if grep -qE "from ['\"]react['\"]|from ['\"]vue['\"]" "$ABS_FILE" 2>/dev/null; then
    VIOLATIONS+="Do not import React or Vue in Astro components. Use Astro component syntax.\n"
  fi
fi

# -----------------------------------------------------------------------
# Page checks
# -----------------------------------------------------------------------
if [[ "$FILE" == src/pages/*.astro || "$FILE" == src/pages/**/*.astro ]]; then
  # Block server endpoints (fetch handlers) -- this is a static site
  if grep -qE 'export (async )?function (GET|POST|PUT|DELETE|PATCH)\b' "$ABS_FILE" 2>/dev/null; then
    # Allow .ts endpoint files (rss.xml.ts, og.png.ts, robots.txt.ts)
    if [[ "$FILE" == *.astro ]]; then
      VIOLATIONS+="No API endpoints in .astro page files. This is a static site.\n"
    fi
  fi
fi

# -----------------------------------------------------------------------
# Config checks
# -----------------------------------------------------------------------
if [[ "$FILE" == src/config.ts ]]; then
  # SITE.website must not be empty in production
  if grep -qE "website:\s*['\"]['\"]" "$ABS_FILE" 2>/dev/null; then
    WARNINGS+="SITE.website is empty. Set it to your deployed domain for canonical URLs and OG images.\n"
  fi
fi

# -----------------------------------------------------------------------
# Structure checks (defense in depth for structureCheck middleware)
# -----------------------------------------------------------------------
if [[ "$FILE" == src/lib/* ]]; then
  VIOLATIONS+="Wrong directory: src/lib/ does not exist. Use src/utils/ for utilities.\n"
fi
if [[ "$FILE" == src/services/* ]]; then
  VIOLATIONS+="Wrong directory: src/services/ does not exist. This is a static blog.\n"
fi
if [[ "$FILE" == src/api/* ]]; then
  VIOLATIONS+="Wrong directory: No API routes. This is a fully static Astro site.\n"
fi
if [[ "$FILE" == src/hooks/* ]]; then
  VIOLATIONS+="Wrong directory: src/hooks/ does not exist. This is Astro, not React.\n"
fi
if [[ "$FILE" == src/store/* ]]; then
  VIOLATIONS+="Wrong directory: No state management. This is a static site.\n"
fi
if [[ "$FILE" == src/types/* ]]; then
  VIOLATIONS+="Wrong directory: Types go in the file that uses them, or in src/env.d.ts.\n"
fi

# -----------------------------------------------------------------------
# Output
# -----------------------------------------------------------------------

if [ -n "$WARNINGS" ]; then
  echo -e "Warnings in $FILE:\n$WARNINGS" >&2
fi

if [ -n "$VIOLATIONS" ]; then
  echo -e "Arch violations in $FILE:\n$VIOLATIONS" >&2
  exit 2
fi

exit 0
