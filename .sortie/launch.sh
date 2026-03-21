#!/usr/bin/env bash
cd '/Users/andrew/projects/blog/.claude/worktrees/BLOG-003'

# Worktree env setup — symlink .env.local + install deps
if [ ! -f .env.local ] && [ -f '/Users/andrew/projects/blog/.env.local' ]; then
  ln -sf '/Users/andrew/projects/blog/.env.local' .env.local
  echo '✓ Symlinked .env.local from base project'
fi
if [ -f pnpm-lock.yaml ]; then
  if [ ! -d node_modules ] || [ pnpm-lock.yaml -nt node_modules ]; then
    echo '📦 Installing dependencies...'
    pnpm install --frozen-lockfile 2>/dev/null || pnpm install
  fi
fi

# Set PREFLIGHT status — agent is on deck, not yet airborne
mkdir -p .sortie
echo '{"status": "PREFLIGHT", "phase": "on deck — pre-launch checks", "timestamp": '"$(date +%s)"'}' > .sortie/flight-status.json

# Cleanup on exit — signal session ended so dashboard sets RECOVERED
cleanup_flight() {
  touch .sortie/session-ended
}
trap cleanup_flight EXIT

printf '\n'
printf '\033[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n'
printf '\033[1;31m        ╔══╗  ╔══╗  ╔══╗  ╔══╗  ╔══╗  ╔══╗  ╔══╗        \033[0m\n'
printf '\033[1;37m           ★ USS TENKARA — FLIGHT OPS ★                   \033[0m\n'
printf '\033[1;36m        CALLSIGN: Ghost-1\033[0m\n'
printf '\033[1;35m        SQUADRON: Ghost\033[0m\n'
printf '\033[1;33m        MODEL:    SONNET\033[0m\n'
printf '\033[2;37m        TRAIT:    cautious\033[0m\n'
printf '\033[1;31m        ╚══╝  ╚══╝  ╚══╝  ╚══╝  ╚══╝  ╚══╝  ╚══╝        \033[0m\n'
printf '\033[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n'
printf '\033[1;37m  "Fight on and fly on to the last drop of fuel to the last beat of the heart."\033[0m\n'
printf '\033[2;37m                          — Baron von Richthofen\033[0m\n'
printf '\033[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n'
printf '\n'
sleep 1
claude --model sonnet 'Read /Users/andrew/projects/blog/.claude/worktrees/BLOG-003/.sortie/directive.md and follow all instructions. Track progress in /Users/andrew/projects/blog/.claude/worktrees/BLOG-003/.sortie/progress.md' --disallowedTools 'Bash(git push --force*)' 'Bash(git push -f *)' 'Bash(git push *--force*)' 'Bash(git push *-f *)' 'Bash(git branch -D:*)' 'Bash(git branch -d:*)' 'Bash(git branch --delete:*)' 'Bash(git clean:*)' 'Bash(git reset --hard:*)' 'Bash(git checkout -- :*)' 'Bash(git restore:*)' 'Bash(rm:*)' 'Bash(rm )' 'Bash(rmdir:*)' 'Bash(unlink:*)' 'Bash(trash:*)' 'Bash(sudo:*)' 'Bash(chmod:*)' 'Bash(chown:*)'
