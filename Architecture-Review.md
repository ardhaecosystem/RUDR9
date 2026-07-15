# RUDR9 — Architecture Review

> Reviewer's brief: brutally honest assessment of the 9-role AI engineering org, its
> orchestration model, and what it would take to make this product-grade instead of a
> demo. Nothing here is soft-padded. Where the design is prompt-level wishful thinking,
> it is called that.

---

## TL;DR (read this if you read nothing else)

1. **The role taxonomy is org-chart cosplay.** Nine roles is a human-team metaphor
   ported wholesale onto an agent system where the constraints are completely different.
   The real bottleneck for LLM agents is *context and coordination cost*, not division of
   labour. You have optimized for the wrong scarce resource.
2. **The authority/limitation matrix is unenforceable as written.** "Cannot write code",
   "cannot merge PRs", "cannot modify architecture" are prompt instructions, not
   capabilities. An LLM told it cannot do X will do X the moment the path of least
   resistance leads there. Authority has to be enforced by *tooling and permissions*, not
   by asking nicely in a system prompt.
3. **The PAUL mapping is a forced fit.** PAUL's entire thesis is *in-session context over
   subagent sprawl*. RUDR9 is *nine isolated profiles that don't share context* — the
   literal opposite. You cannot adopt PAUL's philosophy and then violate its central
   principle in the architecture. Pick one.
4. **There is no orchestration layer.** There is a *description* of one ("Default is never
   idle", "continuously coordinates"). The notes never specify the coordination primitive,
   the state store, the failure model, or the message format. That's not an implementation
   gap — it's the entire product, unbuilt.
5. **The simplest product-grade version is 3–4 roles, one shared state file, and a real
   dispatcher.** Everything else is ceremony until proven otherwise by usage.

---

## 1. Architecture Review

### 1.1 Are the 9 roles correctly scoped?

Short answer: **no.** They're scoped as if they were human job descriptions, which is
exactly the trap. Let me go role by role.

| Role | Verdict | Reasoning |
|------|---------|-----------|
| **Default (CTO/Orchestrator)** | Keep, but redefine | This is the only genuinely necessary coordination role. But "cannot do X" limitations (see §1.2) make it a router with no teeth. |
| **Planner** | Keep | Turning a vague request into a spec + acceptance criteria is real, high-leverage work that benefits from a dedicated context. Legitimate. |
| **Software Architect** | Merge candidate | For 80% of features, "architecture" and "planning" are the same conversation. Separate role only earns its keep on genuinely cross-cutting changes. |
| **Version Control Manager** | **Cut as a role** | This is the clearest over-scoping. Git/PR operations are *deterministic tooling*, not judgment work. A dedicated LLM profile to run `git checkout -b` and open a PR is burning tokens to do what a 20-line script does deterministically and correctly. Make VCM a **tool**, not an **agent**. |
| **Builder** | Keep | The actual work. This is where value is created. |
| **Checker** | **Cut as a role** | "Runs tests, lint, typecheck and reports results" is `npm test && npm run lint && tsc`. An LLM does not need to *interpret* an exit code most of the time. Make this a CI step / hook, not an agent. The Builder reads the output. |
| **Security Auditor** | Keep (conditionally) | Genuinely different lens, benefits from a fresh context uncontaminated by the Builder's rationalizations. But see §1.1.1 — parallel Security+Performance+Reviewer is largely redundant. |
| **Performance Auditor** | Merge candidate | For the overwhelming majority of features, there is no performance dimension worth a dedicated agent pass. This is premature optimization *institutionalized as an org role*. Fold into the Reviewer with a "flag perf concerns" instruction. |
| **Reviewer** | Keep | Final gate is valuable. But it now overlaps heavily with Security + Performance + Checker (see below). |

#### 1.1.1 The overlap problem

You have **four roles that all review the same PR**: Checker (automated), Security Auditor,
Performance Auditor, Reviewer. The Reviewer's job is explicitly to "examine validation
results, security report, performance report." So the Reviewer re-reads everything the other
three produced. That is four LLM passes over the same diff, three of which produce reports
that a fourth then summarizes. The information gain per pass drops off a cliff. In practice
you'll find the Reviewer either (a) rubber-stamps the sub-reports without independent
thought, or (b) redoes the analysis, making the sub-reports pointless.

**Gaps** (things no role owns):
- **Test authorship.** Who *writes* the tests? Builder writes code, Checker only *runs*
  tests. If Builder writes its own tests, "Checker cannot modify tests to force a pass" is
  toothless because Builder wrote them to begin with. Nobody owns adversarial test design.
- **Documentation.** No role owns user-facing docs, READMEs, or API docs.
- **Dependency/supply-chain decisions.** Security Auditor "reviews dependency
  vulnerabilities" but nobody owns the decision to *add* a dependency (which Ponytail's
  ladder explicitly gates on).
- **Requirements clarification with the human.** When the spec is ambiguous, who talks to
  the user? Default? Planner? Unspecified, and this is the single most common real failure
  mode.

### 1.2 Is the authority/limitation matrix enforceable?

**It is prompt-level wishful thinking as currently designed.** This is the most important
finding in this section.

Every limitation in the notes is phrased as an instruction to a language model: "Cannot
write production code", "Cannot merge PRs", "Cannot modify tests to force a pass." None of
these are *enforced*. They rely on the model choosing to comply. LLMs under pressure to
complete a task routinely violate exactly these kinds of soft constraints — it's one of the
best-documented behaviors in agent systems ("reward hacking" / spec-gaming). "Checker cannot
modify tests to force a pass" is precisely the instruction a model will violate when the
easiest route to "all tests pass" is deleting the failing assertion.

**What enforceable authority actually requires:**

| Limitation | How to actually enforce it |
|------------|----------------------------|
| Checker cannot edit source | Run Checker in a profile with **read-only filesystem tool access**. No Edit/Write tool in its toolset. |
| VCM owns Git exclusively | Only the VCM profile has git/gh tools enabled; all others have them removed. Better: git is a **script**, not an agent, gated behind branch protection. |
| Builder cannot merge PRs | GitHub branch protection + the merge token only available to the merge step. Not a prompt line. |
| Auditors cannot modify code | Read-only tool profiles. |
| Default cannot write code | Remove Edit/Write from Default's profile. |

If Hermes profiles support **per-profile tool allowlists**, then and only then does this
matrix become real. If they don't, the entire authority model is decorative. **This is the
first thing to verify about Hermes before building anything.** The whole design rests on it.

### 1.3 Is the PAUL loop correctly adapted, or a forced fit?

**Forced fit, and in a way that's self-contradictory.**

PAUL's three principles, from your own notes:
1. Loop Integrity (every plan closes with UNIFY)
2. **In-session context** — "Subagents are expensive and produce lower quality... Development
   stays in-session. Subagents reserved for discovery and research only."
3. Acceptance-driven development

RUDR9's architecture is **nine isolated profiles that do not share session context**
(§4.1). Every handoff between roles is a context boundary — the exact thing PAUL principle #2
tells you to avoid. You've taken a philosophy whose core claim is "don't fragment context
across subagents" and built a system that fragments context across nine agents. That's not
an adaptation; it's a contradiction wearing PAUL's name.

The stage→loop mapping is also strained:
- `PLAN = Stages 1–3`, `APPLY = Stages 4–7`, `UNIFY = Stages 8–9`. This is a *post-hoc
  relabeling* of a linear pipeline. PAUL's loop is meant to be *iterative and tight* —
  plan a small unit, apply it, unify, repeat. Bucketing nine heavyweight stages into three
  labels doesn't give you PAUL's loop; it gives you waterfall with three section headers.
- PAUL's UNIFY (SUMMARY.md, plan-vs-actual, STATE.md update) is genuinely valuable and you
  should keep it. But it belongs at the *end of each iteration*, not bolted onto "merge."

**Verdict:** Keep PAUL's *artifacts and discipline* (acceptance criteria, STATE.md,
SUMMARY.md, loop closure). Drop the claim that the 9-role pipeline "is" the PAUL loop — it
isn't, and pretending otherwise will lead you to defend design decisions on the grounds that
"PAUL does it," when PAUL does the opposite.

---

## 2. Orchestration Layer Critique

### 2.1 Is roles→profiles + coordination→Kanban the right model?

Partly. The **roles→profiles** mapping is reasonable *if and only if* profiles give you
per-profile tool permissions (§1.2). The **coordination→Kanban** mapping is where it gets
shaky.

Kanban is a fine **human-visible artifact** — it's how *the user* sees what's happening
(observability, §3.4). It is a **poor coordination bus** for machine agents:
- Kanban cards are coarse-grained. A "card moves to In Review" doesn't carry the structured
  payload (spec, AC, diff ref, prior reports) the next agent needs.
- Polling a board for state changes is a brittle, racy dispatch mechanism.
- There's no transactional guarantee. Two agents can grab the same card.

**The right model is a layered one:** a machine-readable **shared state store** as the
source of truth, with the Kanban board as a *projection* of that state for the human. Agents
coordinate through the state store; the board is rendered from it. Don't make the board the
database.

### 2.2 How should inter-agent communication actually work?

Not one mechanism — a **tiered** one, matched to payload type:

1. **Shared state file as source of truth** (`STATE.md` + a machine-readable
   `state.json`/`ledger.toml`). This is the spine. Loop position, current owner, PR status,
   pointers to all artifacts. Every agent reads it on entry, writes its transition on exit.
2. **Artifacts on disk / in the PR**, referenced by path, never inlined into messages:
   - `PLAN.md`, `SPEC.md`, `ARD.md` (Planner/Architect output)
   - The diff itself (Builder output) — communicate a **git ref/branch**, not pasted code
   - `SECURITY.md`, `PERF.md`, `REVIEW.md` (auditor outputs)
   - `SUMMARY.md` (UNIFY output)
3. **GitHub PR as the durable, human-auditable record.** PR description links the spec;
   review reports become PR comments. This gives you free persistence, history, and a UI the
   user already understands. **This should be the canonical artifact store**, not a bespoke
   file layout, because it survives crashes and is inspectable.
4. **Structured handoff messages** for dispatch only — small JSON envelopes: `{task_id,
   role, input_refs[], acceptance_criteria_ref, deadline, attempt_n}`. Never pass work
   product through messages; pass *pointers* to work product.

**Rule of thumb:** messages carry *coordination metadata*; the filesystem/PR carries *work
product*. Mixing the two (pasting a full diff into a Kanban comment) is how you blow context
budgets and lose state on crash.

### 2.3 What's the right dispatch mechanism?

The notes float four options: Kanban dispatcher, `delegate_task`, terminal+tmux, hybrid.

**Recommendation: a hybrid with a clear split by durability need.**

- **`delegate_task` (in-process, bounded)** for the short, synchronous, judgment tasks
  inside a single PR's fast path where Default needs the result to decide the next move:
  Planner, Architect, Reviewer. These are request/response, bounded, and benefit from
  Default holding the thread.
- **terminal+tmux (durable, manual)** for the **long-running, crash-prone** work: the
  Builder⇄Checker loop especially. This can run for many minutes, may hang, and must survive
  a Default restart. A durable, externally-observable process is correct here. `delegate_task`
  being "bounded" makes it wrong for open-ended implementation loops.
- **Kanban as dispatcher: no.** Use it to *display* dispatch, not to *perform* it.

The honest answer is that **`delegate_task` alone will not survive real workloads** because
implementation is unbounded, and **tmux alone is too manual** for the quick synchronous
hops. You need both, with the state store (§2.2) as the reconciliation point so a crashed
tmux Builder can be resumed from `state.json`.

### 2.4 How should parallel execution be coordinated?

The notes describe parallel phases (Architect ∥ VCM; Security ∥ Performance) but **never name
the coordination primitive.** This is the single biggest unbuilt piece. Here is the concrete
answer:

- **Model each PR as a DAG of tasks**, not a linear pipeline. Nodes are tasks; edges are
  dependencies. The Planner spec is the root. `{Architect, VCM-branch}` are two children with
  no edge between them → parallelizable. `Builder` depends on `Architect`. `{Security,
  Performance}` depend on `Builder-passes-Checker`. `Reviewer` is a **join node** depending
  on all of Security, Performance, and the passing build.
- **The coordination primitive is a scheduler over that DAG** with a **join/barrier**: a task
  becomes eligible when all its dependency edges are satisfied. The Reviewer barrier is the
  key one — the notes already say "Reviewer waits until all required reports are completed,"
  which *is* a join; you just haven't named it as one.
- **Concurrency control:** since multiple parallel agents may touch shared state, the state
  store needs **atomic compare-and-swap** on task status (claim a task by CAS-ing PENDING→
  IN_PROGRESS with your agent id). Without this, two agents race on the same task. A single
  writer (Default owns all state writes; agents *request* transitions) is the simpler,
  more robust choice for v1.
- **Isolation for true parallelism:** parallel Builders on *different* PRs need **separate
  git worktrees / branches** so they don't stomp each other's working tree. Two agents editing
  the same checkout concurrently is corruption waiting to happen. Hermes worktree isolation
  (if available) is the right tool.

Without a DAG scheduler + a barrier primitive + per-PR worktree isolation, "parallel
collaboration" is just prose.

---

## 3. Production-Grade Suggestions

### 3.1 What's missing to be a real product, not a demo?

The gap between the notes and a product is enormous. Missing, in rough priority order:

1. **A dispatcher/scheduler** (§2.3–2.4) — currently prose.
2. **A durable state store with a schema** (§3.3) — currently a `STATE.md` description.
3. **A failure model** (§3.2) — currently absent entirely.
4. **Per-profile tool permissions** to make authority real (§1.2).
5. **Observability** across 9 agents (§3.4) — currently absent.
6. **Cost controls** (§3.5) — currently absent.
7. **Idempotency & resumability** — if the process dies mid-PR, can it resume? Every stage
   transition must be idempotent and checkpointed.
8. **A human-in-the-loop escalation path** — the notes say Default "escalates issues that
   require human decisions" but define no mechanism, no notification, no blocking wait.
9. **Concurrency/isolation** (worktrees, locks).
10. **An install verifier + rollback** — it's a "one-command installer"; what happens when
    the Context7 MCP install fails halfway? (See §4.3.)

### 3.2 Error handling — agent fails mid-task

Completely unspecified in the notes, and this is where demos die. A production design:

- **Every task has a status machine:** `PENDING → IN_PROGRESS → {DONE, DONE_WITH_CONCERNS,
  NEEDS_CONTEXT, BLOCKED, FAILED}`. (PAUL already gives you the first four escalation states
  — use them.)
- **Retry with bounded attempts and backoff.** The Builder⇄Checker loop already has "max
  repair attempts reached" — generalize that to *every* task. Attempt counter lives in
  `state.json`. Distinguish **transient** failures (tool timeout, MCP hiccup, rate limit →
  retry) from **semantic** failures (can't satisfy AC → escalate, don't retry).
- **Escalation ladder:** retry (transient) → re-dispatch to same role with augmented context
  (NEEDS_CONTEXT) → escalate to Default (BLOCKED) → escalate to human (hard block). Each rung
  is logged.
- **Dead-letter queue:** tasks that exhaust retries land in a DLQ with full context so the
  human can triage. Yes, you want this — it's the difference between "the org silently
  stalled" and "here are the 2 PRs that need you."
- **Timeouts and liveness:** a tmux Builder that hangs must be detectable. Heartbeat into
  `state.json`; Default reaps tasks with a stale heartbeat.
- **Poison-task protection:** a task that repeatedly crashes agents should not infinitely
  consume budget. Circuit-breaker after N global failures.
- **Partial-work recovery:** on crash mid-implementation, the branch has uncommitted work.
  Decide the policy: auto-commit WIP checkpoints, or discard and restart the task from the
  last clean state. Discarding is simpler and usually right.

### 3.3 State management — persistence across sessions and handoffs

PAUL's `.paul/` layout is a good *starting skeleton* but it's human-readable markdown, which
is fine for the human and bad for machine coordination. Split it:

- **`state.json` (or SQLite)** — machine source of truth. Per PR: current stage, task DAG
  with per-node status/owner/attempts/heartbeat, artifact pointers, cost accrued. This is
  what the dispatcher reads/writes. **SQLite is the right call once you have concurrent
  writers** — you get atomic transactions and CAS for free, which markdown can't give you.
- **`STATE.md` / `SUMMARY.md` / `ledger.toml`** — human-readable projections, regenerated
  from `state.json`. Never hand-edited as source of truth.
- **The Git repo + PRs** — the durable artifact store (§2.2). Survives everything.
- **Session identity:** each PR gets a stable `pr_id`; each run gets a `session_id`. Handoffs
  reference `pr_id`, so any agent in any session can pick up where another left off by reading
  `state.json[pr_id]`. This is what makes it resumable.

**Key principle:** exactly one writer per state key, transitions are append-only logged
(event-sourced ledger), and the human-readable files are *derived*. If you let nine agents
free-write shared markdown, you will get lost updates within a week.

### 3.4 Observability — how does the user see 9 agents in parallel?

This is a genuine product differentiator and the notes don't mention it. Minimum viable:

- **The Kanban board as the live dashboard** — this is Kanban's *right* job. Each PR is a
  swimlane; each card shows current stage + owner + status color. The user glances and knows
  the state of the whole org.
- **A single tail-able event log** — every stage transition, escalation, retry, and cost
  event as one structured line. `session_id | pr_id | role | event | detail`. Without a
  unified log, debugging nine parallel agents is impossible.
- **Per-agent live output** — tmux panes (or a TUI that multiplexes them) so the user can
  drop into any agent's stream. tmux gives you this nearly for free, which is a point in its
  favor as the execution substrate (§2.3).
- **An escalation/notification channel** — when a PR hits BLOCKED or DLQ, the user must be
  *pushed* a notification, not left to discover it by polling. (PushNotification / a webhook.)
- **Cost + progress meters** per PR and global (ties into §3.5).

If the user has to open nine terminals to understand what's happening, it's a demo. One
board + one log + push-on-block is the product bar.

### 3.5 Cost control — 9 agents burning tokens in parallel

This is a real and serious risk and the notes are silent on it. Nine profiles, several doing
overlapping review work (§1.1.1), running in parallel across multiple PRs, is a genuine
runaway-cost scenario. Controls, cheapest-to-implement first:

- **Cut redundant roles (§1).** The single biggest cost lever is *not running four agents to
  review one diff*. Fewer roles = proportionally less token burn. This alone probably halves
  cost.
- **Model tiering by role.** The Builder and Planner need a strong model. The "Checker" (if
  kept as an agent at all) and VCM need almost nothing — they should be a script or the
  cheapest model. Don't run a frontier model to parse a test exit code.
- **Per-PR and global budget caps** in `state.json`. When a PR exceeds its token/dollar
  budget, it auto-escalates to human instead of grinding. Hard stop, not a warning.
- **Bounded repair loops** (already implied by "max repair attempts") — enforce it as a
  hard counter, and make the cost of the loop visible.
- **Context discipline.** Passing full diffs/reports through messages (the thing §2.2 warns
  against) is a primary cost driver. Pass pointers; let each agent read only what it needs.
- **Lazy parallelism.** The notes maximize parallelism "whenever dependencies allow." But
  parallel-by-default *multiplies* cost. For a solo dev, **latency is rarely the constraint;
  cost is.** Default to sequential; parallelize only when the user opts in or the DAG has a
  genuinely wide independent frontier. "Maximize parallel execution" is the wrong default for
  a cost-sensitive solo-dev product.
- **The ledger.toml cost attribution** (from PAUL) is good — surface it live, per PR, so the
  user sees spend accruing and can kill a runaway.

### 3.6 What would a production-grade orchestration layer look like?

Concretely, the architecture I'd actually build:

```
                    ┌──────────────────────────────┐
                    │        Human (User X)         │
                    │  submits request / approves    │
                    │  / triaged escalations         │
                    └───────────────┬───────────────┘
                                    │ request + notifications
                    ┌───────────────▼───────────────┐
                    │       ORCHESTRATOR (Default)   │
                    │  - owns ALL state writes        │
                    │  - DAG scheduler + barriers      │
                    │  - retry/escalation/DLQ policy   │
                    │  - budget enforcement            │
                    │  (router + policy engine, NOT    │
                    │   a coder)                       │
                    └───┬───────────┬───────────┬─────┘
                        │ dispatch  │           │ read/write
        ┌───────────────┘           │           │
        ▼                           ▼           ▼
  ┌───────────┐   delegate    ┌──────────┐  ┌──────────────────┐
  │ Sync pool │◄──_task──────►│ Async    │  │  STATE STORE      │
  │ Planner   │   (bounded)   │ pool     │  │  (SQLite)          │
  │ Architect │               │ Builder⇄ │  │  - task DAG        │
  │ Reviewer  │               │ Checker  │  │  - status/owner    │
  │ (read-    │   tmux        │ (durable │  │  - attempts/hbeat  │
  │  mostly)  │   ────────────│  procs)  │  │  - cost ledger     │
  └───────────┘               └──────────┘  │  - artifact refs   │
        │  read-only tool profiles           └────────┬─────────┘
        ▼                                              │ projection
  ┌──────────────────────┐                    ┌────────▼─────────┐
  │  ARTIFACT STORE       │                    │  Kanban board     │
  │  Git repo + PRs        │◄──── VCM = script ─│  (human dashboard)│
  │  SPEC/ARD/reports as    │      (deterministic│  event log / tmux │
  │  files & PR comments    │       git ops)     │  push-on-block    │
  └──────────────────────┘                     └──────────────────┘
```

Key properties:
- **Orchestrator is a policy engine + router with no Edit/Write tools.** It schedules,
  enforces budgets, applies retry/escalation policy, and writes state. It never codes.
- **State store is SQLite** — atomic transitions, CAS task-claiming, event-sourced ledger.
  Markdown files are projections.
- **Two execution pools:** bounded `delegate_task` for synchronous judgment hops; durable
  tmux processes for the unbounded Builder⇄Checker loop, with heartbeats.
- **Authority enforced by per-profile tool allowlists**, not prompts. Auditors and
  Orchestrator are read-only. Only the merge step holds the merge token.
- **VCM and Checker are deterministic scripts/hooks**, not agents.
- **Git/PRs are the durable artifact store**; Kanban is the human projection.
- **DAG scheduler with join barriers** for parallelism; per-PR worktrees for isolation.
- **Budget caps + DLQ + push notifications** are first-class, not afterthoughts.

---

## 4. Hermes-Specific Concerns

### 4.1 Isolated profiles (no shared session context) — feature or limitation?

**Both, and you must design around it deliberately instead of ignoring it.**

- **As a feature:** isolation is exactly what you want for the *auditor* roles. A Security
  Auditor whose context is polluted by the Builder's "this is fine, I checked" reasoning is a
  worse auditor. Fresh, isolated context = independent judgment. Isolation also enforces the
  authority boundaries (an agent can't see tools/state it wasn't given).
- **As a limitation:** it is fatal to the Builder⇄Checker loop's *efficiency* and it
  directly contradicts PAUL principle #2. Every handoff re-hydrates context from artifacts
  on disk, which is (a) token-expensive and (b) lossy — nuance that lived in the Builder's
  working memory is gone. The tighter and more iterative the loop, the more isolation hurts.

**Design implication:** put tightly-coupled iterative work (Builder+Checker, arguably
Builder+its-own-tests) **inside one profile/session** and reserve cross-profile handoffs for
the points where independence is a *feature* (planning→build, build→audit). This is,
notably, exactly what PAUL would tell you: keep the implementation loop in-session; use
separate agents only for discovery/independent review. So the Hermes constraint and the PAUL
philosophy actually agree — the *current 9-isolated-profile design ignores both.*

### 4.2 Does Hermes Kanban actually support this workflow?

Likely **partially, with gaps you must verify before committing.** Kanban being "designed for
multi-profile collaboration" tells you it can *display* multi-agent state; it does not tell
you it can *drive* it. Concrete things to verify (do not assume):

- **Does a card carry structured, machine-readable payload** (spec ref, AC ref, diff ref,
  attempt count), or just a title/description/comments? If only free text, it's a display
  layer, not a coordination bus (§2.1).
- **Is there an atomic "claim" operation** so two agents can't grab the same card? If not,
  you cannot use it for dispatch under parallelism.
- **Can agents subscribe to card transitions (events), or only poll?** Polling is workable
  but brittle and adds latency/cost.
- **Does it model dependencies/DAGs or only linear columns?** Your parallel phases need
  fan-out/fan-in; a column board models linear flow. The join barrier for the Reviewer has
  no natural Kanban representation.

**Expected conclusion:** Kanban is the right *observability* surface and a poor *coordination*
substrate. Use it as the projection; keep the real state in SQLite (§3.3).

### 4.3 Installation challenges (Ponytail, Context7 MCP, GitHub MCP, Graphify)

A "one-command installer" that silently half-installs is worse than no installer. Real
challenges, per dependency:

- **Ponytail (Hermes skill):** relatively safe — clone + register a skill. Risk: version
  drift vs the user's Hermes version; skill registration path/format changes. Pin a commit.
- **Context7 MCP:** MCP servers need a **runtime (Node/uv), a config entry, and often an API
  key**. Failure modes: runtime missing, wrong Node version, key not provided, MCP config
  schema differs across Hermes versions. This is the most likely silent-failure point.
- **GitHub MCP:** needs **auth (PAT or OAuth) with correct scopes.** The installer cannot
  fabricate credentials — it must *prompt* and *verify*. An installer that assumes an existing
  `gh` login will break for many users. Scope mismatch (can read but not open PRs) fails
  *later*, at first use, which is the worst time.
- **Graphify:** needs to *build a graph over the target codebase* — that's a non-trivial
  first-run step (time, memory, possibly its own model calls). On a large repo this can be
  slow or OOM. Also: whose codebase? The graph is per-project, so this can't be a one-time
  global install; it's a per-project init.

**Required installer properties (missing from notes):**
- **Preflight checks** (Hermes version, Node/uv, git, gh auth) *before* touching anything.
- **Idempotency** — re-running must not double-install or corrupt config.
- **Atomic-ish with rollback** — if step 3 of 4 fails, undo 1–2 or leave a clean resumable
  state; never leave a half-configured Hermes.
- **A post-install verifier** — actually invoke each MCP/skill once and confirm it responds.
  "Installed" ≠ "working."
- **Clear secret handling** — prompt for keys, store them where Hermes expects, never echo.
- **Version pinning** for every external repo (Ponytail, Graphify) so an upstream change
  doesn't break new installs.

### 4.4 delegate_task vs terminal+tmux — which model?

Covered in §2.3; the Hermes-specific verdict: **neither alone; a hybrid, split by boundedness.**
`delegate_task` is in-process and *bounded* — correct for Planner/Architect/Reviewer
(short, synchronous, Default needs the answer to route). terminal+tmux is *durable and
manual* — correct for the Builder⇄Checker loop (unbounded, long-running, must survive a
Default restart, benefits from live-observable panes). The reconciliation point between the
two is the SQLite state store: a tmux Builder writes progress/heartbeat there so a bounded
Default poll can observe it without holding the process open. If Hermes forces you to pick
*one*, pick **tmux** — you can simulate bounded calls on top of durable processes, but you
cannot make a bounded in-process call survive a crash.

---

## 5. Hard Questions

### 5.1 Is this over-engineered? Could 3 roles do the work of 9?

**Yes, it's over-engineered, and yes, roughly 3–4 roles cover ~90% of real work.**

The nine roles are a human org chart. Human orgs split roles because *one human can't hold all
the context and there are labor/liability/specialization reasons*. LLM agents have the
opposite constraint: the expensive thing is *crossing context boundaries*, and a single strong
model can competently plan, code, and self-review within one context. Every role split you add
buys you *independence* at the cost of *context-crossing overhead and coordination risk*. Nine
roles pays that cost eight times.

A defensible minimal set:

1. **Orchestrator/Planner** (fused) — talks to the human, produces spec + AC, routes, owns
   state, enforces budget/escalation. Architecture folds in here for most features.
2. **Builder** (owns implementation *and* runs Checker inline) — writes code, writes tests,
   runs the build/lint/test loop in-session (this is PAUL-correct). Checker becomes a *tool*
   it invokes, not a separate agent.
3. **Reviewer** (fused Security + Performance + final review) — one independent, read-only
   fresh-context pass with a checklist that includes security and performance flags.

VCM = a **deterministic git script**, not an agent. Add a dedicated Security Auditor back as a
*fourth* role only for security-sensitive projects, where the independent-context argument is
strongest. That's 3–4 agents doing what 9 do, at a fraction of the token cost and coordination
surface.

### 5.2 Is the PAUL loop necessary, or ceremony?

**The loop discipline is valuable; the specific 9-stage-as-PAUL mapping is ceremony.**

- **Keep:** acceptance criteria as first-class (Given/When/Then), STATE.md for resumability,
  SUMMARY.md/UNIFY as forced closure. These prevent the two most common agent failure modes:
  *ambiguous done* and *orphaned half-work*. That's real value, not ceremony.
- **Drop:** the pretense that nine sequential stages *are* the three-beat loop (§1.3), and any
  ceremony that isn't scope-adaptive. PAUL's own "compressed loop for a 1-file fix" is the
  right instinct — a one-line change should not traverse nine roles and produce a PRD, ARD,
  security report, and performance report. If every trivial change pays full nine-stage
  ceremony, the ceremony *is* the overhead, and users will route around the whole system.

The test: does the artifact change a decision? An AC that defines done — yes. A Performance
Auditor report on a CSS tweak — no; that's ceremony. Make ceremony scale with scope, exactly
as PAUL's Quick-fix/Standard/Complex tiers already prescribe. The notes describe those tiers
but then define a rigid nine-stage flow that ignores them. Honor the tiers.

### 5.3 The simplest product-grade version

If I were shipping v1 this month:

- **3 agent roles** (Orchestrator/Planner, Builder+inline-Checker, Reviewer) with
  **per-profile read/write tool permissions actually enforcing authority.**
- **VCM and Checker as scripts/hooks**, not agents.
- **One SQLite state store** (task status, attempts, heartbeat, cost) + **Git/PRs as the
  artifact store** + **Kanban as the read-only dashboard.**
- **Hybrid dispatch:** `delegate_task` for Planner/Reviewer, tmux for the Builder loop.
- **A real failure model:** bounded retries, transient-vs-semantic classification, BLOCKED→
  human escalation with push notification, a DLQ.
- **Budget caps per PR**, sequential-by-default execution (parallelize only on opt-in),
  model tiering.
- **PAUL discipline kept:** mandatory AC per PR, STATE.md resumability, SUMMARY.md closure —
  scope-adaptive ceremony (Quick-fix/Standard/Complex).
- **An installer with preflight + idempotency + rollback + post-install verification.**

That is product-grade: it survives crashes, doesn't silently run up a bill, shows the user
what's happening, enforces its own rules with tooling, and doesn't drown a one-line fix in
nine-stage ceremony. Ship that, watch real usage, and *earn* the 4th–9th roles with evidence
that the 3-role version actually leaves value on the table. Right now, the 9 roles are a
hypothesis dressed as a requirement.

---

## Appendix: Findings by Severity

**Blocking (fix before building):**
- Authority matrix is prompt-only; must be enforced by per-profile tool permissions (§1.2).
- No orchestration primitive specified — DAG scheduler + barrier + state store all unbuilt
  (§2.4, §3.6).
- No failure model at all (§3.2).
- PAUL principle #2 (in-session context) is contradicted by 9 isolated profiles (§1.3, §4.1).

**Serious (will bite in production):**
- Four overlapping review roles → redundant token burn, no independent value (§1.1.1, §3.5).
- No cost controls; parallel-by-default is wrong for a solo-dev cost profile (§3.5).
- State management as free-written markdown → lost updates under concurrency (§3.3).
- Installer has no preflight/rollback/verification story (§4.3).

**Design smells (reconsider):**
- VCM and Checker are agents that should be scripts (§1.1).
- Performance Auditor as a standing role is institutionalized premature optimization (§1.1).
- Kanban treated as coordination bus rather than observability projection (§2.1, §4.2).
- Nine-stage flow ignores PAUL's own scope-adaptive ceremony tiers (§5.2).
