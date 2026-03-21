(legacy worktree agent)
Branch: sortie/blog-003

---
## Flight Status Protocol
Report your flight status by writing to `.sortie/flight-status.json`:
```json
{"status": "AIRBORNE", "phase": "implementing auth refresh", "timestamp": 1710345600}
```
Valid statuses: PREFLIGHT, AIRBORNE, HOLDING, ON_APPROACH, RECOVERED
Update on meaningful phase transitions only (starting new task area, running tests, submitting PR, blocked, done). Do NOT update on every tool call.
Use unix timestamp (seconds). Phase is a short human-readable description of what you're doing.
PREFLIGHT is set automatically before launch — do not write it yourself.
Write AIRBORNE only when you start actively making changes (editing files, running commands, writing code). Reading context, reading tickets, reading files, and planning are all still PREFLIGHT.
Write HOLDING when you are waiting/blocked/idle.
NEVER write RECOVERED — that is set automatically when your session ends.
When your mission is complete, write HOLDING with phase 'mission complete — awaiting orders'.

## Server Port Protocol
If you start any dev server, worker, or dashboard process, write the port to `.sortie/server-ports.json`:
```json
{"dev": 3001, "bullboard": 4502, "timestamp": 1710345600}
```
Include any port your worktree is serving on. The TUI reads this to show server URLs on the board and the O key opens them in the browser. Update the file whenever a new server starts or a port changes.

## Sibling Coordination (pull-parent protocol)
If you see a file at `.sortie/pull-parent.json`, a sibling agent has merged their work into the parent branch. Read the file for details, then:
1. Run `git pull origin <branch>` (branch is in the JSON file)
2. Resolve any merge conflicts
3. Delete `.sortie/pull-parent.json`
4. Continue your work with the updated code
