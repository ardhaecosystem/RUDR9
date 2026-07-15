# RUDR9 — Hermes Agent Integration Plan

> How RUDR9 integrates into Hermes Agent. Based on verified Hermes docs:
> profiles, hooks, plugins, MCP, Kanban, AGENTS.md, and the installer script.

---

## 1. Profiles — The Role Foundation

Each RUDR9 role becomes a Hermes profile. Verified capabilities:

### Profile Creation
```bash
# Clone from default (inherits config, .env, SOUL.md, skills)
hermes profile create planner --clone --description "Transforms requirements into engineering specifications. Cannot write code."
hermes profile create architect --clone --description "Designs technical solutions. Cannot implement or commit code."
hermes profile create vcm --clone --description "Owns Git workflow and PR lifecycle. Cannot write application logic."
hermes profile create builder --clone --description "Implements approved specifications. Cannot change requirements or merge PRs."
hermes profile create security --clone --description "Reviews PRs for security risks. Cannot modify implementation."
hermes profile create performance --clone --description "Evaluates runtime efficiency. Cannot rewrite implementation."
hermes profile create reviewer --clone --description "Final engineering quality gate. Cannot edit code or merge PRs."
```

The `--description` flag is critical — **Kanban's auto-decomposer reads profile descriptions to route tasks to the right specialist.** This is the orchestration glue.

### What Each Profile Gets Isolated
- `config.yaml` — model, provider, toolsets (authority enforcement)
- `.env` — API keys (can share or isolate per role)
- `SOUL.md` — role identity, authority, limitations
- `skills/` — role-specific skills
- `sessions/` + `state.db` — isolated session history
- `memories/` — isolated memory
- `cron/` — isolated scheduled jobs
- `plugins/` — isolated plugin config

### Default Profile = CTO/Orchestrator
The existing default profile (`~/.hermes/`) becomes the orchestrator. We don't create a new profile — we *modify* the existing one:
- Update `SOUL.md` with CTO identity
- Configure `kanban.orchestrator_profile: default` in config.yaml
- Remove Edit/Write tools from its toolset (enforces "cannot write code")
- Install orchestration skills

### Profile Command Aliases
Each profile auto-gets a command alias at `~/.local/bin/<name>`:
```bash
planner chat          # chat with the Planner agent
builder chat          # chat with the Builder agent
security chat         # chat with the Security Auditor
# etc.
```

### Authority Enforcement via Per-Profile Toolsets
This is the keystone. Hermes supports per-profile tool configuration:
```bash
# Planner: no terminal write, no file write, no git
planner config set tools.disabled terminal,file,git
# or via hermes tools:
planner tools disable terminal
planner tools disable file

# Security Auditor: read-only (no file write, no terminal)
security tools disable file
security tools disable terminal

# Reviewer: read-only
reviewer tools disable file
reviewer tools disable terminal

# Default (CTO): no code writing — router only
hermes tools disable file
```

**Toolset matrix per profile:**

| Profile | terminal | file | web | code_execution | delegation | kanban | git/MCP |
|---------|----------|------|-----|----------------|------------|--------|---------|
| Default (CTO) | ✗ | ✗ | ✓ | ✗ | ✓ | ✓ | GitHub MCP |
| Planner | ✗ | ✗ read | ✓ | ✗ | ✗ | ✓ | ✗ |
| Architect | ✗ | ✗ read | ✓ | ✗ | ✗ | ✓ | ✗ |
| VCM | ✓ git only | ✗ | ✗ | ✗ | ✗ | ✓ | GitHub MCP |
| Builder | ✓ | ✓ | ✗ | ✓ | ✗ | ✓ | Context7 |
| Security | ✗ | ✗ read | ✓ | ✗ | ✗ | ✓ | ✗ |
| Performance | ✗ | ✗ read | ✓ | ✗ | ✗ | ✓ | ✗ |
| Reviewer | ✗ | ✗ read | ✓ | ✗ | ✗ | ✓ | ✗ |

---

## 2. Kanban — The Coordination + Visibility Layer

Verified Hermes Kanban capabilities that RUDR9 leverages:

### Board Initialization
```bash
hermes kanban init                    # creates kanban.db (SQLite)
```

### Orchestrator Config
```yaml
# ~/.hermes/config.yaml
kanban:
  orchestrator_profile: default       # CTO owns the root task
  auto_decompose: false               # Manual mode — CTO controls decomposition
  dispatch_in_gateway: true           # dispatcher runs in gateway process
  failure_limit: 2                    # auto-block after 2 consecutive failures
  max_in_progress: 3                  # cap concurrent tasks (cost control)
  max_in_progress_per_profile: 1      # one task per role at a time (sequential default)
```

### How the 9-Stage Workflow Maps to Kanban

The CTO creates tasks on the board. Each task is assigned to a profile. The dispatcher spawns the assigned profile as a worker.

**Stage 1 — Planning:**
```
CTO creates task → assignee: planner
Planner produces SPEC.md, writes to task body/comments
Planner completes task with summary
```

**Stage 2 — Architecture:**
```
CTO creates task → assignee: architect, links to planning task
Architect produces ARD.md, writes to task body/comments
Architect completes task
```

**Stage 3 — VCM Branch Setup:**
```
CTO creates task → assignee: vcm, links to architecture task
VCM creates feature branch, initializes PR draft
VCM completes task
```

**Stage 4-5 — Implementation + Validation (fused Builder+Checker):**
```
CTO creates task → assignee: builder, links to architecture + VCM tasks
Builder implements, runs inline validation (test/lint/typecheck)
Builder completes task with validation results
```

**Stage 6-7 — Security + Performance Review (parallel):**
```
CTO creates two tasks:
  → assignee: security, links to builder task
  → assignee: performance, links to builder task
Both run in parallel (if max_in_progress allows)
Each writes findings to task comments
```

**Stage 8 — Final Review:**
```
CTO creates task → assignee: reviewer, links to ALL prior tasks
Reviewer reads all comments/artifacts, produces verdict
Approved → CTO proceeds; Changes Requested → task back to builder
```

**Stage 9 — Merge:**
```
CTO creates task → assignee: vcm, links to reviewer task
VCM merges PR, updates version history, closes PR
VCM completes task
```

### Task Linking = DAG Dependencies
Kanban supports `kanban_link(parent_id, child_id)` — this gives us the dependency graph. A child task is not promoted until its parent completes. This is the **join barrier** Opus said was missing — it's built into Kanban's dependency model.

### Worker Context Injection
When the dispatcher spawns a worker, it automatically injects:
- Task title, body, and all comments (prior agents' output)
- Workspace directory (isolated per task)
- Kanban toolset (`kanban_show`, `kanban_complete`, `kanban_block`, etc.)
- Auto-injected kanban guidance (lifecycle instructions)

This means **artifacts flow through task comments and linked task chains** — the Planner's spec is readable by the Architect because they're linked tasks on the same board.

### Failure Handling (Built-In)
- Stale claim reclamation — dead workers don't hold tasks forever
- Auto-block after `failure_limit` consecutive spawn failures
- `kanban_block` with reason routing (needs_context → escalate, blocked → human)
- Heartbeat system for long operations (`kanban heartbeat`)

### Scope-Adaptive Ceremony
The CTO controls how many tasks to create per feature:
- **Quick-fix:** 1 task → builder (inline validation) → vcm merge. 3 stages, not 9.
- **Standard:** planner → architect → vcm → builder → reviewer → vcm merge. 6 stages.
- **Complex:** Full 9-stage with parallel security + performance.

This is the cost control mechanism — the CTO decides ceremony level per feature.

---

## 3. SOUL.md — Role Identity + Authority

Each profile gets a `SOUL.md` at `~/.hermes/profiles/<name>/SOUL.md`:

### Structure
```markdown
# [Role Name]

## Identity
You are the [Role] in the RUDR9 AI Engineering Organization.

## Authority
[What this role can do — specific, enumerated]

## Limitations
[What this role cannot do — specific, enumerated]
If you encounter a problem outside your responsibility, escalate via kanban_block.

## Workflow
[How this role receives work, produces output, and hands off]

## Artifacts
[What this role produces and where it writes them]
```

### Soft Enforcement + Hard Enforcement
- **Soft:** SOUL.md tells the model what it can/cannot do (prompt-level)
- **Hard:** Toolset restrictions prevent the action (capability-level)
- **Defense in depth:** Both layers active. If the model ignores SOUL.md, it literally doesn't have the tools to violate the constraint.

---

## 4. AGENTS.md — Project-Level Instructions

RUDR9 creates an `AGENTS.md` in the user's project directory. This is auto-loaded by Hermes when working in that project.

### Purpose
- Tells all profiles working in this project about the RUDR9 workflow
- Defines the `.rudr9/` project structure
- Sets coding standards, branch naming, commit conventions
- References the Kanban board as the coordination source of truth

### Structure
```markdown
# RUDR9 Project — [Project Name]

## Engineering Organization
This project uses the RUDR9 AI Engineering Organization.
All work flows through the Kanban board. Check `hermes kanban list` for active tasks.

## Project Structure
.rudr9/
├── PROJECT.md           # Project context and requirements
├── ROADMAP.md           # Phase breakdown
├── STATE.md             # Current loop position
├── phases/
│   └── <phase>/
│       ├── PLAN.md      # Specification
│       ├── ARD.md       # Architecture design
│       ├── SUMMARY.md   # UNIFY closure
│       └── reports/
│           ├── SECURITY.md
│           ├── PERFORMANCE.md
│           └── REVIEW.md

## Conventions
- Branch naming: feature/<name>, bugfix/<name>, hotfix/<name>
- Conventional Commits: feat:, fix:, refactor:, docs:, chore:
- All changes through PRs — no direct commits to main
- Acceptance criteria in BDD format: Given/When/Then

## Rules
- Every feature is a Kanban task chain
- No agent edits another agent's work directly
- All decisions flow through the Default (CTO) profile
- Git operations owned exclusively by VCM
```

### Discovery Rules (Verified)
- `AGENTS.md` is loaded from **cwd only** (not parent walk)
- First match wins — only one project context file loads per session
- 20K character cap (head+tail truncated if larger)
- Passes through threat-pattern scanner before reaching the model
- `hermes --ignore-rules` skips all context files for isolation

---

## 5. Skills — Role-Specific Capabilities

Each profile gets skills installed relevant to its role:

### All Profiles
- `rudr9-workflow` — core RUDR9 workflow knowledge (stages, handoffs, artifacts)
- `ponytail` — lazy senior developer philosophy (simplification ladder)

### Planner
- `rudr9-planning` — specification writing, BDD acceptance criteria

### Architect
- `rudr9-architecture` — system design, PRD/ARD templates
- `graphify` — codebase knowledge graph queries
- `context7` (via MCP) — up-to-date library docs

### VCM
- `github-pr-workflow` — PR lifecycle, branch management
- `github-repo-management` — repo operations
- `github-code-review` — PR review operations

### Builder
- `rudr9-implementation` — coding standards, validation loop
- `context7` (via MCP) — library docs during implementation
- `test-driven-development` — TDD discipline
- `graphify` — codebase navigation

### Security Auditor
- `rudr9-security-review` — security review checklist, OWASP reference

### Performance Auditor
- `rudr9-performance-review` — performance review checklist

### Reviewer
- `rudr9-final-review` — comprehensive review checklist
- `requesting-code-review` — pre-merge review process

### Skill Installation
```bash
# Install to a specific profile
planner skills install github.com/ArdhaStudios/rudr9-planning
# Install ponytail to all profiles (done in installer script)
for profile in default planner architect vcm builder security performance reviewer; do
  hermes -p $profile skills install github.com/DietrichGebert/ponytail
done
```

---

## 6. MCP Servers — External Tool Integration

### Context7 MCP (Architect, Builder)
```yaml
# Added to architect and builder profile config.yaml
mcp_servers:
  context7:
    command: "npx"
    args: ["-y", "@upstash/context7-mcp"]
```

```bash
# Or via CLI per profile
hermes -p architect mcp add context7 --command "npx" --args '-y @upstash/context7-mcp'
hermes -p builder mcp add context7 --command "npx" --args '-y @upstash/context7-mcp'
```

### GitHub MCP (Default, VCM, Reviewer)
```bash
# Via catalog (Nous-approved, one-click)
hermes -p default mcp install github
hermes -p vcm mcp install github
hermes -p reviewer mcp install github
```
Requires `GITHUB_PERSONAL_ACCESS_TOKEN` in each profile's `.env`. The installer prompts for this.

### Per-Server Tool Filtering
Hermes supports per-MCP tool filtering — VCM gets PR/merge tools, Reviewer gets read-only PR tools:
```bash
hermes -p vcm mcp configure github      # select: create_pr, merge_pr, create_branch
hermes -p reviewer mcp configure github # select: get_pr, review_pr, add_comment
```

### Graphify (Already a Skill)
Graphify is installed as a Hermes skill, not an MCP. It's available to profiles that have the `skills` toolset enabled. Per-project graph generation via `graphify update .`.

---

## 7. Hooks — Lifecycle Automation

### Gateway Hooks (for monitoring/alerts)
Located at `~/.hermes/hooks/<name>/HOOK.yaml + handler.py`. Fire on gateway events.

**RUDR9 Board Activity Hook:**
```yaml
# ~/.hermes/hooks/rudr9-activity/HOOK.yaml
name: rudr9-activity
description: Notify on Kanban task state changes
events:
  - command:*
```

**RUDR9 Long-Task Alert:**
```yaml
# ~/.hermes/hooks/rudr9-long-task/HOOK.yaml
name: rudr9-long-task
description: Alert when a worker agent runs too many steps
events:
  - agent:step
```
Fires when any worker exceeds N iterations — potential stuck loop.

### Plugin Hooks (for tool interception/guardrails)
Via `ctx.register_hook()` in a plugin. Available in both CLI and gateway.

**RUDR9 Authority Guard Plugin:**
A plugin that intercepts tool calls and blocks violations:
- If Planner profile tries to call `write_file` → block
- If Security Auditor tries to call `terminal` → block
- If Builder tries to call `git merge` → block

This is **belt + suspenders** on top of toolset restrictions. Even if a toolset is misconfigured, the plugin hook catches it.

### Shell Hooks (for auto-formatting, context injection)
Via `hooks:` block in config.yaml. Drop-in shell scripts.

**Post-Write Auto-Format:**
```yaml
# ~/.hermes/config.yaml
hooks:
  post_file_write:
    command: "ruff check --fix {{file_path}} 2>/dev/null; prettier --write {{file_path}} 2>/dev/null"
```

---

## 8. The Installer Script — `rudr9-install.sh`

Modeled on Hermes's own `install.sh` pattern. Bash, cross-platform, idempotent.

### Structure
```bash
#!/bin/bash
set -e

# RUDR9 Installer — transforms Hermes Agent into a 9-role AI engineering org

# --- Preflight ---
check_hermes_installed()      # hermes --version must succeed
check_git_available()         # git --version
check_node_available()        # node --version (for MCP servers)
check_github_auth()           # gh auth status or GITHUB_TOKEN in env
check_existing_rudr9()        # detect prior install, offer upgrade

# --- Phase 1: Profile Creation ---
create_profiles() {
  # Clone from default for each role
  for role in planner architect vcm builder security performance reviewer; do
    if ! hermes profile list | grep -q "^$role"; then
      hermes profile create $role --clone --description "${DESCRIPTIONS[$role]}"
    fi
  done
  echo "✓ 7 profiles created (Default becomes CTO)"
}

# --- Phase 2: SOUL.md Installation ---
install_souls() {
  # Write role-specific SOUL.md to each profile
  for role in default planner architect vcm builder security performance reviewer; do
    cp "$ASSETS_DIR/SOUL-$role.md" "$(profile_path $role)/SOUL.md"
  done
}

# --- Phase 3: Toolset Configuration ---
configure_toolsets() {
  # Per-profile tool restrictions (hard authority enforcement)
  hermes tools disable file          # Default: no code writing
  hermes tools disable terminal
  
  planner tools disable terminal
  planner tools disable file
  
  security tools disable file
  security tools disable terminal
  
  performance tools disable file
  performance tools disable terminal
  
  reviewer tools disable file
  reviewer tools disable terminal
  # VCM: terminal enabled (git ops), file disabled
  # Builder: terminal + file + code_execution enabled
}

# --- Phase 4: Skill Installation ---
install_skills() {
  # Ponytail to all profiles
  for role in default planner architect vcm builder security performance reviewer; do
    hermes -p $role skills install github.com/DietrichGebert/ponytail --enable
  done
  
  # Role-specific skills
  planner skills install github.com/ArdhaStudios/rudr9-planning --enable
  architect skills install github.com/ArdhaStudios/rudr9-architecture --enable
  # ... etc
}

# --- Phase 5: MCP Installation ---
install_mcps() {
  # Context7 for architect + builder
  hermes -p architect mcp add context7 --command "npx" --args "-y @upstash/context7-mcp"
  hermes -p builder mcp add context7 --command "npx" --args "-y @upstash/context7-mcp"
  
  # GitHub MCP for default, vcm, reviewer
  for role in default vcm reviewer; do
    hermes -p $role mcp install github
  done
  
  # Graphify (already a skill, just ensure enabled)
  for role in architect builder reviewer; do
    hermes -p $role skills enable graphify
  done
}

# --- Phase 6: Kanban Board Setup ---
setup_kanban() {
  hermes kanban init
  # Configure orchestrator settings
  hermes config set kanban.orchestrator_profile default
  hermes config set kanban.auto_decompose false
  hermes config set kanban.dispatch_in_gateway true
  hermes config set kanban.failure_limit 2
  hermes config set kanban.max_in_progress 3
  hermes config set kanban.max_in_progress_per_profile 1
}

# --- Phase 7: Hooks ---
install_hooks() {
  cp -r "$ASSETS_DIR/hooks/rudr9-activity" ~/.hermes/hooks/
  cp -r "$ASSETS_DIR/hooks/rudr9-long-task" ~/.hermes/hooks/
}

# --- Phase 8: Plugin (Authority Guard) ---
install_plugin() {
  cp -r "$ASSETS_DIR/plugins/rudr9-guard" ~/.hermes/plugins/
  hermes plugins enable rudr9-guard
}

# --- Phase 9: Post-Install Verification ---
verify_install() {
  echo "Verifying installation..."
  hermes profile list | grep -c "rudr9" | grep -q 7 || fail "Not all profiles created"
  for role in planner architect vcm builder security performance reviewer; do
    hermes -p $role doctor || warn "$role profile health check failed"
  done
  hermes mcp list | grep -q context7 || warn "Context7 MCP not configured"
  hermes mcp list | grep -q github || warn "GitHub MCP not configured"
  hermes kanban stats >/dev/null 2>&1 || fail "Kanban board not initialized"
  echo "✓ RUDR9 installation verified"
}

# --- Phase 10: Project-Level Init ---
init_project() {
  # Create .rudr9/ structure in current directory
  mkdir -p .rudr9/phases
  cp "$ASSETS_DIR/AGENTS.md" ./AGENTS.md
  cp "$ASSETS_DIR/PROJECT.md" .rudr9/PROJECT.md
  cp "$ASSETS_DIR/STATE.md" .rudr9/STATE.md
  echo "✓ Project initialized with .rudr9/ structure"
}

# --- Main ---
main() {
  parse_args "$@"
  preflight
  create_profiles
  install_souls
  configure_toolsets
  install_skills
  install_mcps
  setup_kanban
  install_hooks
  install_plugin
  verify_install
  init_project  # optional, --with-project flag
  echo ""
  echo "🚀 RUDR9 is ready. Run 'hermes kanban list' to see the board."
}
```

### Installer Properties
- **Preflight checks** — Hermes, git, node, gh auth all verified before touching anything
- **Idempotent** — re-running skips already-created profiles, doesn't double-install
- **Per-profile error handling** — one profile failing doesn't abort the whole install
- **Post-install verification** — actually probes each component
- **Project init** — optional `--with-project` flag creates `.rudr9/` in cwd
- **Rollback** — `--uninstall` flag removes all RUDR9 profiles, hooks, plugins, resets Kanban

### Distribution
```bash
# One-line install
curl -fsSL https://ardhastudios.com/rudr9/install.sh | bash

# Or via npm/npx (like PAUL)
npx rudr9 install

# Or as a Hermes skill
hermes skills install github.com/ArdhaStudios/rudr9
```

---

## 9. RUDR9 Plugin — The Authority Guard

A Hermes plugin that enforces role boundaries at the tool-call level, as a safety net on top of toolset restrictions.

### Structure
```
~/.hermes/plugins/rudr9-guard/
├── plugin.yaml          # manifest
├── __init__.py          # register() — hooks pre_tool_call
├── rules.py             # role → allowed tools mapping
└── schemas.py           # (none — no tools, just hooks)
```

### Logic
```python
# rules.py
ROLE_TOOL_MAP = {
    "planner":     {"allowed": ["read_file", "search_files", "web_search", "web_extract", "kanban_*"]},
    "architect":   {"allowed": ["read_file", "search_files", "web_search", "web_extract", "kanban_*"]},
    "vcm":         {"allowed": ["terminal", "read_file", "search_files", "kanban_*", "mcp_github_*"]},
    "builder":     {"allowed": ["terminal", "read_file", "write_file", "patch", "search_files", "code_execution", "kanban_*", "mcp_context7_*"]},
    "security":    {"allowed": ["read_file", "search_files", "web_search", "kanban_*"]},
    "performance": {"allowed": ["read_file", "search_files", "web_search", "kanban_*"]},
    "reviewer":    {"allowed": ["read_file", "search_files", "web_search", "kanban_*", "mcp_github_*"]},
}

# __init__.py
def register(ctx):
    ctx.register_hook("pre_tool_call", on_tool_call)

def on_tool_call(tool_name, params, **kwargs):
    profile = os.environ.get("HERMES_PROFILE", "default")
    allowed = ROLE_TOOL_MAP.get(profile, {}).get("allowed", [])
    # Check if tool_name matches any allowed pattern (support wildcards)
    if not matches_allowed(tool_name, allowed):
        return {"block": True, "reason": f"Role '{profile}' cannot use '{tool_name}'"}
    return None  # allow
```

---

## 10. Complete Integration Flow

```
User X installs Hermes Agent
        │
        ▼
User X runs: curl ... | rudr9-install.sh
        │
        ├── Creates 7 profiles (planner, architect, vcm, builder, security, performance, reviewer)
        ├── Writes SOUL.md to each profile (role identity + authority)
        ├── Configures per-profile toolsets (hard enforcement)
        ├── Installs skills (ponytail + role-specific)
        ├── Installs MCPs (Context7, GitHub)
        ├── Initializes Kanban board + dispatcher
        ├── Installs hooks (activity monitor, long-task alert)
        ├── Installs rudr9-guard plugin (authority enforcement)
        ├── Verifies everything works
        └── Optionally initializes .rudr9/ in project dir
        │
        ▼
User X: "Build me a user authentication feature"
        │
        ▼
Default (CTO) receives request
        │
        ├── Creates Kanban task: "Plan user auth" → assignee: planner
        ├── Dispatcher spawns Planner profile
        ├── Planner produces SPEC.md, posts to task comments, completes task
        │
        ├── CTO creates task: "Design auth architecture" → assignee: architect (linked to planning)
        ├── Dispatcher spawns Architect profile
        ├── Architect produces ARD.md, posts to task comments, completes task
        │
        ├── CTO creates task: "Create feature branch" → assignee: vcm (linked to architecture)
        ├── VCM creates branch, drafts PR, completes task
        │
        ├── CTO creates task: "Implement user auth" → assignee: builder (linked to architecture + VCM)
        ├── Builder implements, runs inline validation, completes task
        │
        ├── CTO creates 2 parallel tasks: security + performance (linked to builder)
        ├── Both run simultaneously (if max_in_progress allows)
        ├── Each posts findings to task comments
        │
        ├── CTO creates task: "Final review" → assignee: reviewer (linked to ALL prior)
        ├── Reviewer reads all artifacts, produces verdict
        │
        └── CTO creates task: "Merge PR" → assignee: vcm (linked to reviewer)
            VCM merges, closes PR, completes task
        │
        ▼
Feature complete. Kanban board shows full audit trail.
```

---

## Key Design Decisions Summary

| Decision | Rationale |
|----------|-----------|
| 9 profiles (not 3) | Context isolation = cost saving per call; fresh context for auditors = independent judgment |
| Builder+Checker fused | Tightly coupled iterative loop; in-session validation avoids context handoff overhead |
| Kanban as coordination bus | Built-in dispatcher, atomic claiming, task linking (DAG), stale reclamation, auto-block on failure, user-visible dashboard |
| Manual decompose mode | CTO controls task creation — scope-adaptive ceremony (Quick-fix/Standard/Complex) |
| Per-profile toolsets | Hard enforcement of authority matrix — model physically lacks the tools to violate constraints |
| Plugin guard | Belt + suspenders on toolset restrictions — catches misconfigurations |
| SOUL.md per profile | Soft enforcement + role identity — tells the model what it is and what it can/cannot do |
| AGENTS.md per project | Project-level instructions auto-loaded by all profiles working in that directory |
| Sequential-by-default | `max_in_progress_per_profile: 1` — parallelism is opt-in, not default (cost control) |
| Bash installer | Matches Hermes pattern, no deps, cross-platform, idempotent |
