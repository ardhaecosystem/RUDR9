# [Project Name]

> This project uses the RUDR9 AI Engineering Organization.
> All work flows through the Hermes Kanban board.

## Engineering Organization

| Role | Profile | Responsibility |
|------|---------|----------------|
| CTO / Orchestrator | `default` | Coordinates workflow, assigns tasks, monitors progress |
| Planner | `planner` | Specifications, acceptance criteria |
| Software Architect | `architect` | Technical design, API contracts, system structure |
| Version Control Manager | `vcm` | Git workflow, branches, PRs, merges |
| Builder | `builder` | Implementation + inline validation |
| Security Auditor | `security` | Security review of every PR |
| Performance Auditor | `performance` | Performance review of every PR |
| Reviewer | `reviewer` | Final quality gate before merge |

## How to Start Work

```bash
# Check active tasks
hermes kanban list

# See what's assigned to a role
hermes kanban list --assignee builder
```

The CTO (default profile) creates tasks on the Kanban board. The dispatcher
spawns the assigned profile as a worker. Workers read task context, do the
work, and post results to task comments.

## Project Structure

```
.rudr9/
├── PROJECT.md           # This file — project context
├── STATE.md             # Current loop position
└── phases/
    └── <phase-name>/
        ├── PLAN.md      # Specification (Planner output)
        ├── ARD.md       # Architecture design (Architect output)
        ├── SUMMARY.md   # Closure (UNIFY output)
        └── reports/
            ├── SECURITY.md
            ├── PERFORMANCE.md
            └── REVIEW.md
```

## Conventions

- **Branch naming:** `feature/<name>`, `bugfix/<name>`, `hotfix/<name>`, `docs/<name>`, `refactor/<name>`
- **Commits:** Conventional Commits — `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`
- **All changes through PRs** — no direct commits to `main`
- **Acceptance criteria:** BDD format — `Given [precondition] / When [action] / Then [outcome]`

## Rules

- Every feature is a Kanban task chain.
- No agent edits another agent's work directly.
- All decisions flow through the Default (CTO) profile.
- Git operations owned exclusively by the VCM.
- Every feature closes with UNIFY (SUMMARY.md).
- Authority is enforced by per-profile toolsets + the rudr9-guard plugin.