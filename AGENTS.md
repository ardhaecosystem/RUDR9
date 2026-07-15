# RUDR9

## What This Is

One-command installer that transforms Hermes Agent into a 9-role AI engineering organization. Profiles, Kanban coordination, per-profile authority enforcement, PAUL-inspired workflow.

## Repo Layout

- `install.sh` — the installer (preflight → profiles → SOULs → toolsets → skills → MCPs → Kanban → hooks → plugin → verify)
- `assets/souls/` — 8 SOUL.md role templates
- `assets/plugins/rudr9-guard/` — authority enforcement plugin (pre_tool_call hook)
- `assets/hooks/rudr9-long-task/` — stuck loop alert
- `assets/templates/` — project init files (AGENTS.md, PROJECT.md, STATE.md)
- `Dockerfile` — isolated test environment

## Development

```bash
# Dry run (no changes)
./install.sh --dry-run

# Guard plugin tests
cd assets/plugins/rudr9-guard
python3 -c "
import sys; sys.path.insert(0, '.')
from rules import is_allowed
assert not is_allowed('planner', 'write_file')
assert is_allowed('builder', 'write_file')
assert not is_allowed('security', 'terminal')
print('ok')
"

# Full Docker test
docker build -t rudr9-test .
docker run -d --name rudr9-test rudr9-test tail -f /dev/null
docker exec -d rudr9-test bash -lc 'cd /home/rudr9/RUDR9 && ./install.sh > /tmp/install.log 2>&1'
# wait ~8 min
docker exec rudr9-test bash -lc 'hermes profile list && hermes kanban assignees'
docker rm -f rudr9-test
```

## Conventions

- Conventional Commits: `feat:`, `fix:`, `docs:`, `refactor:`
- Branch naming: `feat/`, `fix/`, `docs/`
- All changes through PRs — no direct commits to main
- Test before pushing: `./install.sh --dry-run` must pass

## Key Design Decisions

- Guard plugin reads `HERMES_PROFILE` env var (set by Kanban dispatcher when spawning workers) — NOT `HERMES_HOME` basename
- Builder+Checker fused into one profile (in-session validation loop)
- Kanban is coordination bus + user dashboard (not just display)
- Sequential-by-default (`max_in_progress_per_profile: 1`) — parallelism is opt-in
- Install backs up SOUL.md before overwriting; uninstall restores