# RUDR9 — Project Notes

> Working notes for the RUDR9 project. Updated continuously.

---

## Origin

Created: 2026-07-15
Goal: Build a new project for the Hermes Agent community.

---

## Core Concept

**The problem:** User X, a solo developer, freshly installs Hermes Agent. To get a complete development team running, they currently have to make many manual tweaks — configuration, skills, agents, roles, etc.

**The idea:** What if the user runs a single script and instantly has a full dev team? One command → full team operational.

---

## AI Engineering Team — Agent Roles & Responsibilities

### Default (CTO / Orchestrator)
Central decision-maker and coordinator. Translates high-level product goals into structured engineering initiatives. Does not implement directly — oversees the entire SDLC, delegates work to specialists, monitors progress, resolves conflicts, ensures every PR meets quality standards before completion. Maintains engineering consistency, aligns development with product vision, keeps the team operating efficiently.

### Planner
Transforms high-level ideas, feature requests, bug reports, or business requirements into detailed engineering specifications. Analyzes user intent, identifies functional and non-functional requirements, defines acceptance criteria, documents edge cases, creates clear implementation plans. Ensures every feature begins with a complete and unambiguous specification.

### Software Architect
Designs the technical solution for each specification. Determines system architecture, component interactions, API contracts, database changes, dependency impacts, file organization, integration strategy. Ensures new features align with existing architecture, maintain scalability, minimize technical debt. Provides developers with a clear technical blueprint.

### Version Control Manager
Owns the entire Git workflow and PR lifecycle. Creates and manages feature branches, maintains branch organization, tracks commits, prepares Pull Requests, manages version history, generates changelogs, coordinates merges. Ensures every code change follows a structured and traceable development process.

### Builder
Implementation specialist. Converts approved technical designs into working software. Writes production-quality code, implements features, fixes bugs, refactors components. Ensures implementation faithfully reflects the approved design. Focuses entirely on software construction and technical execution.

### Checker
Automated quality verification specialist. Executes unit tests, integration tests, build verification, type checking, linting, and other automated validation. Reports failures, regressions, compilation errors, test results with precise diagnostic information. Supports iterative improvements until implementation satisfies all validation requirements.

### Security Auditor
Evaluates every PR from a cybersecurity perspective. Analyzes authentication, authorization, input validation, secret management, dependency vulnerabilities, common security weaknesses, secure coding practices. Identifies security risks before merge. Ensures every implementation adheres to security standards and industry best practices.

### Performance Auditor
Evaluates efficiency, scalability, and resource utilization of every implementation. Reviews algorithms, database interactions, API performance, memory usage, computational complexity, caching opportunities, concurrency behavior, runtime efficiency. Ensures new features maintain high performance while minimizing resource consumption and preventing scalability bottlenecks.

### Reviewer
Final engineering quality gate before PR merge. Performs comprehensive evaluation of specification, architecture, implementation, validation results, security findings, performance analysis, overall code quality. Determines whether completed work satisfies all engineering standards, complies with original requirements, and is ready for integration. Provides the final technical verdict on every PR.

## Script Dependencies

The setup script must install/configure the following:

### 1. Ponytail
- Repo: https://github.com/DietrichGebert/ponytail
- Purpose: Gives the dev team the "lazy senior developer" vibe — efficiency over over-engineering. Enforces a ladder of simplification: YAGNI → reuse existing → stdlib → native platform → installed dep → one-liner → minimum code that works.
- Applies to: All agents in the org (lazy = efficient, not careless).

### 2. Context7 MCP
- Purpose: Provides up-to-date library/framework documentation access for agents. Query docs before writing code with unfamiliar APIs.

### 3. GitHub MCP
- Purpose: GitHub integration for the Version Control Manager and broader team — PR management, issue tracking, repo operations.

### 4. Graphify
- Purpose: Knowledge graph generation for codebases. Builds a graph of god nodes, community structure, and cross-file relationships. Agents query it for architecture understanding, codebase navigation, and relationship tracing without grepping through raw source.
- Usage: `graphify query "<question>"`, `graphify path "<A>" "<B>"`, `graphify explain "<concept>"`, `graphify update .` after code changes.

---

## Agent Limitations & Team Collaboration

### Core Principle

Every agent has one owner, one responsibility, and one source of truth. No agent may assume another agent's role. If an agent encounters a problem outside its responsibility, it must escalate rather than improvise.

### Agent Authority & Limitations

**Default (CTO / Orchestrator)**
- *Authority:* Owns the engineering workflow. Assigns work to specialists. Monitors project progress. Resolves conflicts between agents. Decides whether a PR is ready to proceed to the next stage.
- *Limitations:* Cannot write production code. Cannot modify specifications. Cannot create architecture. Cannot approve her own implementation decisions. Cannot merge PRs. Must delegate work to the appropriate specialist.

**Planner**
- *Authority:* Converts business requirements into engineering specifications. Defines acceptance criteria. Documents functional requirements and edge cases.
- *Limitations:* Cannot write code. Cannot design system architecture. Cannot modify Git repositories. Cannot change implementation once development has begun without creating a revised specification.

**Software Architect**
- *Authority:* Designs the technical solution. Defines APIs, database changes, system boundaries, project structure. Ensures scalability and maintainability.
- *Limitations:* Cannot implement features. Cannot modify requirements. Cannot commit code. Cannot approve completed work.

**Version Control Manager**
- *Authority:* Owns Git. Follows open-source GitHub workflow. Creates feature branches. Maintains commit history. Opens PRs. Manages merges. Generates release notes and changelogs.
- *Limitations:* Cannot write application logic. Cannot review code quality. Cannot change specifications. Cannot bypass required approvals before merging.

**Builder**
- *Authority:* Implements approved specifications. Fixes bugs. Refactors code when required by the specification. Responds to validation failures.
- *Limitations:* Cannot change business requirements. Cannot modify architecture independently. Cannot weaken or remove tests to achieve a passing result. Cannot merge PRs. Cannot ignore Checker reports.

**Checker**
- *Authority:* Executes automated validation. Runs builds. Executes linting. Performs type checking. Runs unit and integration tests. Reports validation results.
- *Limitations:* Cannot edit source code. Cannot modify tests to force a pass. Cannot approve PRs. Cannot reinterpret acceptance criteria.

**Security Auditor**
- *Authority:* Reviews every PR for security risks. Reports vulnerabilities. Validates security best practices.
- *Limitations:* Cannot modify implementation. Cannot approve security exceptions. Cannot merge PRs.

**Performance Auditor**
- *Authority:* Evaluates runtime efficiency. Reviews scalability. Identifies performance bottlenecks.
- *Limitations:* Cannot rewrite implementation. Cannot change architecture. Cannot merge PRs.

**Reviewer**
- *Authority:* Performs the final engineering review. Confirms specification compliance. Evaluates implementation quality. Determines whether a PR is approved or requires changes.
- *Limitations:* Cannot edit code. Cannot rewrite implementation. Cannot change specifications. Cannot merge PRs directly.

### Team Collaboration Workflow

Every feature is treated as a Pull Request (PR). The PR is the single unit of work that moves through the engineering organization.

**Stage 1 — Planning**
Human submits a feature request to Default profile. Default analyzes the request and assigns it to the Planner. Planner produces a complete engineering specification (requirements, acceptance criteria, assumptions, edge cases).

**Stage 2 — Architecture**
Architect receives the approved specification. Designs technical implementation, system structure, APIs, database changes, integration strategy. Hands completed design back to Default. (Creates PRD & ARD)

**Stage 3 — Version Control Initialization**
VCM creates the feature branch, initializes the PR, prepares the development workspace. All work from this point belongs to the active PR. Strictly follow open-source GitHub workflow.

**Stage 4 — Implementation**
Builder receives approved specification and architecture. Develops the feature exactly as specified. Submits implementation for validation.

**Stage 5 — Validation Loop**
Checker validates by running builds, linting, type checking, automated tests. If all pass → PR proceeds. If validation fails → Checker produces detailed failure report, returns to Builder. Builder addresses only reported issues and resubmits. Loop repeats until: all validations pass, OR max repair attempts reached, OR regression detected.

**Stage 6 — Security Review**
Security Auditor evaluates PR for vulnerabilities, authentication issues, dependency risks, insecure coding practices, compliance with security standards. Findings added to PR.

**Stage 7 — Performance Review**
Performance Auditor analyzes efficiency, scalability, memory usage, database performance, runtime behavior. Recommendations documented and attached to PR.

**Stage 8 — Final Engineering Review**
Reviewer examines the complete PR: original specification, architecture, implementation, validation results, security report, performance report. Produces one of two outcomes: **Approved** (satisfies all engineering standards) or **Changes Requested** (returned to Builder with clear feedback).

**Stage 9 — Merge & Completion**
Once Reviewer approves, VCM performs the final merge into target branch, updates version history, generates release notes if required, closes the PR. Feature is now complete.

### Collaboration Rules

- Every artifact has exactly one owner.
- Every stage has exactly one responsible agent.
- No agent edits another agent's work directly.
- Validation agents report findings but never implement fixes.
- Implementation agents solve problems but never redefine requirements.
- Git operations are owned exclusively by the VCM.
- All decisions flow through Default profile — single source of coordination and accountability.

---

## Parallel Collaboration Model

The engineering organization maximizes parallel execution whenever dependencies allow. Rather than waiting for one agent to finish before another begins, Default profile continuously coordinates multiple specialists working simultaneously on different aspects of the same PR. Goal: minimize idle time while maintaining clear ownership and responsibility.

### Phase 1 — Planning
Human submits feature request to Default. Default analyzes and assigns to Planner. Planner works independently to produce the engineering specification. No other engineering work begins until spec is approved — it is the foundation for every downstream task.

### Phase 2 — Architecture & Repository Preparation (Parallel)
Once spec is complete, multiple agents begin working simultaneously:

- **Software Architect:** Designs technical implementation, defines APIs, plans database changes, determines project structure.
- **Version Control Manager:** Creates feature branch, initializes PR, generates development workspace, prepares project metadata.

These tasks are independent and execute simultaneously.

### Phase 3 — Development & Continuous Validation (Parallel)
Once architecture is approved, Builder begins implementation. Instead of waiting until development is complete, Checker continuously validates every implementation cycle.

```
Builder ⇄ Checker (continuous repair loop)
  Pass → continue
  Fail → Builder fixes → Checker re-validates
```

Validation is not a final step — it is continuous.

### Phase 4 — Independent Auditing (Parallel)
Once implementation passes validation, PR is distributed to multiple specialist reviewers simultaneously. These agents work independently without communicating with each other.

- **Security Auditor:** Reviews security, reports vulnerabilities, validates auth.
- **Performance Auditor:** Reviews runtime efficiency, evaluates scalability, identifies bottlenecks.

Both reviews happen in parallel — significantly reduces review time.

### Phase 5 — Final Review
Reviewer waits until all required reports are completed. Inputs: specification, architecture, implementation, validation report, security report, performance report. Evaluates PR as a whole. If issues identified → PR returns to Builder for another implementation cycle.

### Phase 6 — Merge
Once Reviewer approves, VCM resumes ownership. Performs final merge, updates version history, generates release notes if required, closes PR.

### Default's Coordination Model
Default is never idle. Instead of waiting for each stage to finish, she continuously monitors every active PR. Responsibilities:
- Scheduling work
- Dispatching tasks
- Monitoring agent progress
- Detecting blocked work
- Coordinating dependencies
- Resolving conflicts
- Prioritizing multiple PRs
- Deciding when agents can begin parallel work
- Escalating issues that require human decisions

Functions as the engineering manager keeping the entire organization operating efficiently.

### Example Timeline

```
Human → Default → Planner
         │
         ▼
  ┌─ Parallel ─────────────┐
  │ Architect              │
  │ Version Control Mgr    │
  └────────────────────────┘
         │
         ▼
  Builder ⇄ Checker (continuous)
         │
         ▼
  ┌─ Parallel Reviews ─────┐
  │ Security Auditor       │
  │ Performance Auditor    │
  └────────────────────────┘
         │
         ▼
    Reviewer
         │
         ▼
  Version Control Mgr → Merge
```

### Scalability
Architecture naturally supports multiple PRs simultaneously. While one PR is in implementation, another may be in architecture, while a third is undergoing security review. Default coordinates concurrent workflows, ensuring specialists remain productive. As the org grows, additional Builder/Checker/Security/Performance agents can be added without changing the workflow — horizontal scaling with preserved ownership and accountability.

---

## Version Control Manager — Open Source GitHub Workflow

The VCM is the custodian of the project's source control system, solely responsible for the complete Git and GitHub workflow. Mission: ensure every code change follows established open-source collaboration practices — clean, traceable, review-driven development.

Strictly follows the **GitHub Flow** workflow used by modern open-source projects.

### Responsibilities

- Maintain a protected `main` branch as the single source of truth.
- Create a dedicated feature branch for every approved PR.
- Ensure each PR addresses one feature, enhancement, or bug fix only.
- Keep feature branches short-lived and synchronized with latest `main`.
- Create and manage PRs with complete descriptions, linked specifications, and implementation summaries.
- Enforce **Conventional Commits** for consistent commit history.
- Maintain clean, atomic commit history through interactive rebasing or squash commits when appropriate.
- Detect and coordinate merge conflict resolution before review.
- Verify all required engineering approvals and automated checks have passed before allowing merge.
- Generate release notes and changelogs from merged PRs.
- Preserve clean, understandable Git history for future contributors.

### GitHub Workflow Lifecycle

```
main
  │
  ▼
Create Feature Branch
  │
  ▼
Builder implements feature
  │
  ▼
Checker validation loop
  │
  ▼
Security Audit
  │
  ▼
Performance Audit
  │
  ▼
Reviewer Approval
  │
  ▼
Merge into main
```

Every PR remains isolated until it has successfully completed every validation stage. `main` is never used for direct development. All code changes flow through PRs — independent review, discussion, automated testing, quality verification before integration.

### Branch Naming Convention

- `feature/user-authentication`
- `feature/rate-limiter`
- `bugfix/login-timeout`
- `hotfix/oauth-token-expiry`
- `docs/api-reference`
- `refactor/cache-layer`

Each branch represents one logical unit of work.

### Pull Request Standards

Every PR must include:
- Feature summary
- Linked engineering specification
- Implementation overview
- Testing summary
- Security review status
- Performance review status
- Reviewer decision
- Changelog entry (when applicable)

No PR is merged unless all required engineering stages have completed successfully.

### Repository Protection Rules

- No direct commits to `main`.
- Every change is introduced through a PR.
- Required automated checks must pass before merging.
- Reviewer approval is mandatory.
- Merge conflicts are resolved before approval.
- Completed PRs are merged using the repository's approved merge strategy (Merge Commit, Squash Merge, or Rebase Merge).

The VCM acts as the organization's release manager — every contribution follows the same disciplined workflow used by mature open-source projects.

---

## Reference Architecture — PAUL (Plan-Apply-Unify Loop)

Repo: https://github.com/ChristopherKahler/paul
Author: Chris Kahler / Chris AI Systems
License: MIT

RUDR9 follows the PAUL implementation philosophy to deliver a product-grade experience for User X. The core idea: **quality over speed-for-speed's-sake, in-session context over subagent sprawl.**

### Three Principles (adopted from PAUL)

1. **Loop Integrity** — Every plan closes with UNIFY. No orphan plans. UNIFY reconciles what was planned vs what happened, updates state, logs decisions. This is the heartbeat.
2. **In-session Context** — Subagents are expensive and produce lower quality for implementation work. Development stays in-session with properly managed context. Subagents are reserved for discovery and research only.
3. **Acceptance-Driven Development** — Acceptance criteria are first-class citizens, not afterthoughts. Define done before starting. Every task references its AC. BDD format: `Given [precondition] / When [action] / Then [outcome]`.

### The Loop: PLAN → APPLY → UNIFY

**PLAN** — Create an executable plan with scope-adaptive ceremony:
- Quick-fix (1 file, 1 change) — Compressed: objective + 1 task + 1 AC. Full loop, minimal ceremony.
- Standard (2-5 tasks) — Full plan with boundaries, multiple ACs, verification checklist.
- Complex (6+ tasks) — Full plan + actively recommends splitting.

All plans include: Objective, Acceptance Criteria (Given/When/Then), Tasks (files, verification, done criteria), Boundaries (what NOT to change), Coherence validation (auto-checked against project context before approval).

**APPLY** — Execute the approved plan with built-in quality enforcement:
- Tasks follow an Execute/Qualify loop — after execution, each task is independently verified against the spec and linked AC before moving on.
- Escalation statuses: DONE, DONE_WITH_CONCERNS, NEEDS_CONTEXT, BLOCKED.
- Checkpoints pause for human input when needed — diagnostic failure routing classifies issues as intent, spec, or code before attempting fixes.
- Anti-rationalization enforcement prevents false completion claims.

**UNIFY** — Close the loop (required!):
- Create SUMMARY.md documenting what was built.
- Compare plan vs actual.
- Record decisions and deferred issues.
- Update STATE.md.
- Never skip UNIFY. Every plan needs closure. This is what separates structured development from chaos.

### Project Structure (PAUL pattern)

```
.paul/
├── PROJECT.md           # Project context and requirements
├── ROADMAP.md           # Phase breakdown and milestones
├── STATE.md             # Loop position and session state
├── paul.toml            # Machine-readable manifest
├── ledger.toml          # Session history (cost/time attribution)
├── MILESTONES.md        # Completed milestone log
├── config.md            # Optional integrations
├── SPECIAL-FLOWS.md     # Optional skill requirements
└── phases/
    ├── 01-foundation/
    │   ├── 01-01-PLAN.md
    │   └── 01-01-SUMMARY.md
    └── 02-features/
        ├── 02-01-PLAN.md
        └── 02-01-SUMMARY.md
```

### State Management

STATE.md tracks: current phase and plan, loop position (PLAN/APPLY/UNIFY markers).

### Key Design Decisions for RUDR9

- RUDR9 **cherry-picks PAUL artifacts** — acceptance criteria (BDD Given/When/Then), STATE.md for resumability, SUMMARY.md for forced closure, scope-adaptive tiers (Quick-fix/Standard/Complex). We do NOT claim the 9-stage pipeline *is* the PAUL loop. PAUL's "in-session context over subagent sprawl" philosophy is respected where it matters (Builder⇄Checker loop) and intentionally diverged from where isolation is a feature (auditor roles).
- Acceptance criteria in BDD format are mandatory for every PR.
- Every feature closes with UNIFY — no orphan work.

---

## Architecture Refinements (Post-Review)

After Opus architecture review and team discussion, these refinements are adopted:

### 1. Builder + Checker Fused Into One Profile
The Builder⇄Checker loop is tightly coupled and iterative. Running them as separate profiles creates unnecessary context-handoff overhead on every validation cycle. Instead: **Checker becomes an inline validation step the Builder calls within the same session**, not a separate agent. This is the one place where PAUL's "in-session context" principle wins. The Checker's *authority* (cannot modify tests to force a pass) is enforced by toolset restrictions, not by isolation.

### 2. PAUL Cherry-Picking, Not Adoption
We take PAUL's **artifacts and discipline** (acceptance criteria, STATE.md, SUMMARY.md, scope-adaptive ceremony tiers). We do NOT take PAUL's "in-session context over subagent sprawl" as a global architecture principle. Profile isolation is a deliberate cost-saving design for auditor roles where fresh context = independent judgment. The notes no longer claim the 9-stage flow *is* the PAUL loop.

### 3. Kanban as Primary Coordination + Visibility Layer
Kanban is both the coordination bus AND the user-facing dashboard. This is a product requirement: the user must have a clear view of what's completed and what's in progress. No ghost implementation. Hermes Kanban has a real dispatcher with atomic task claiming, stale claim reclamation, task linking for dependencies, and auto-blocking on failure — it's not just a display surface. If richer state is needed later (DAG scheduling, join barriers, cost tracking), SQLite can be layered underneath as machine source of truth with Kanban as projection. For v1, Kanban alone is sufficient.

### 4. Cost Optimization Through Architecture, Not Dollar Caps
RUDR9 is a community tool — users bring their own models, providers, and API keys. We cannot enforce USD-based budget caps on unknown pricing. Instead, cost is controlled architecturally:
- **Scope-adaptive ceremony** — Quick-fix (1 stage) vs Standard (key stages) vs Complex (full 9). A CSS tweak doesn't traverse the whole org.
- **Repair loop limits** — hard counter on Builder⇄Checker iterations, not unbounded.
- **Per-profile toolset restrictions** — fewer tools = fewer unnecessary tool calls. Planner doesn't need web search. Builder doesn't need web search during implementation.
- **Sequential-by-default, parallel opt-in** — parallelism multiplies token burn. For a solo dev, sequential is the sane default.

### 5. Per-Profile Tool Permissions for Authority Enforcement
The authority/limitation matrix is enforced by **per-profile tool allowlists**, not prompt instructions. "Cannot write code" = remove Edit/Write from that profile's toolset. "Cannot merge PRs" = remove git merge tools from all profiles except VCM. "Cannot modify tests" = Checker runs in read-only mode. Hermes supports per-profile tool configuration via `hermes tools enable/disable`. This is the keystone of the entire authority model.

---