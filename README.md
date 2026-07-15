# RUDR9

**One command → full AI engineering team.**

RUDR9 transforms a fresh [Hermes Agent](https://hermes-agent.nousresearch.com) installation into a 9-role AI engineering organization with structured workflows, parallel execution, and product-grade quality gates.

```bash
curl -fsSL https://ardhastudios.com/rudr9/install.sh | bash
```

## What You Get

| Role | Profile | Responsibility |
|------|---------|----------------|
| CTO / Orchestrator | `default` | Coordinates workflow, assigns tasks, monitors progress |
| Planner | `planner` | Specifications, BDD acceptance criteria |
| Software Architect | `architect` | Technical design, API contracts, system structure |
| Version Control Manager | `vcm` | Git workflow, branches, PRs, merges |
| Builder | `builder` | Implementation + inline validation |
| Security Auditor | `security` | Security review of every PR |
| Performance Auditor | `performance` | Performance review of every PR |
| Reviewer | `reviewer` | Final quality gate before merge |

Each role is a Hermes profile with:
- Isolated config, memory, sessions, and skills
- Per-profile toolset restrictions (hard authority enforcement)
- SOUL.md defining identity, authority, and limitations
- Role-specific skills and MCP servers

## How It Works

```
User: "Build me a user authentication feature"
  │
  ▼
CTO (default) receives request
  │
  ├── Creates Kanban task → Planner produces SPEC.md
  ├── Creates task → Architect produces ARD.md
  ├── Creates task → VCM creates feature branch + draft PR
  ├── Creates task → Builder implements + runs inline validation
  ├── Creates parallel tasks → Security + Performance review
  ├── Creates task → Reviewer gives final verdict
  └── Creates task → VCM merges PR
  │
  ▼
Feature complete. Full audit trail on the Kanban board.
```

The CTO controls ceremony level per feature:
- **Quick-fix** (1 file): Builder → VCM merge
- **Standard** (2-5 tasks): Planner → Architect → VCM → Builder → Reviewer → VCM merge
- **Complex** (6+ tasks): Full 9-stage with parallel security + performance

## Key Features

- **Per-profile tool permissions** — the Planner physically cannot write code (no `file` tool). The Security Auditor physically cannot modify implementation (no `terminal`/`file` write). Authority enforced by tooling, not prompts.
- **Kanban coordination** — Hermes's built-in Kanban dispatcher handles task assignment, dependency linking (DAG), stale worker reclamation, and auto-blocking on failure. The board is the user-visible dashboard.
- **rudr9-guard plugin** — belt + suspenders authority enforcement at the tool-call level.
- **PAUL discipline** — BDD acceptance criteria (Given/When/Then), STATE.md for resumability, SUMMARY.md for forced closure. Scope-adaptive ceremony.
- **Ponytail** — lazy senior developer philosophy installed on all profiles. Efficiency over over-engineering.
- **Cost control** — sequential-by-default execution (`max_in_progress_per_profile: 1`), scope-adaptive ceremony, repair loop limits (5 max).

## Installation

### Prerequisites

- [Hermes Agent](https://hermes-agent.nousresearch.com) installed and configured
- Git, Node.js (for MCP servers)
- GitHub CLI authenticated (for VCM role)

### Install

```bash
# From this repo
./install.sh

# With project initialization (.rudr9/ + AGENTS.md in current dir)
./install.sh --with-project

# Dry run (see what would happen)
./install.sh --dry-run

# Uninstall
./install.sh --uninstall
```

### What the installer does

1. Creates 7 Hermes profiles (planner, architect, vcm, builder, security, performance, reviewer)
2. Writes SOUL.md (role identity + authority) to each profile
3. Configures per-profile toolsets (hard authority enforcement)
4. Installs Ponytail skill on all profiles
5. Installs Context7 MCP (architect, builder) + GitHub MCP (default, vcm, reviewer)
6. Initializes Kanban board with CTO as orchestrator
7. Installs long-task alert hook + rudr9-guard plugin
8. Verifies all components

## Project Structure After Install

```
~/.hermes/
├── SOUL.md                    # CTO identity (modified)
├── config.yaml                # Kanban orchestrator config added
├── hooks/
│   └── rudr9-long-task/       # Stuck loop alert
├── plugins/
│   └── rudr9-guard/           # Authority enforcement plugin
└── profiles/
    ├── planner/
    │   ├── SOUL.md
    │   ├── config.yaml
    │   └── skills/            # ponytail + planning skills
    ├── architect/
    ├── vcm/
    ├── builder/
    ├── security/
    ├── performance/
    └── reviewer/
```

## Architecture Decisions

- **9 profiles, not 3** — context isolation saves cost per call; fresh context for auditors = independent judgment
- **Builder + Checker fused** — tightly coupled iterative loop runs in-session (PAUL-correct)
- **Kanban as coordination bus** — built-in dispatcher with atomic claiming, DAG dependencies, failure handling
- **Sequential-by-default** — parallelism is opt-in (cost control for solo devs)
- **PAUL artifacts, not philosophy** — cherry-picked acceptance criteria, STATE.md, SUMMARY.md, scope tiers

See [Integration-Plan.md](Integration-Plan.md) for the full technical design and [Architecture-Review.md](Architecture-Review.md) for the Opus architecture review.

## License

MIT

## Built By

[Ardha Studios](https://github.com/ArdhaStudios) — Veda & Humanth