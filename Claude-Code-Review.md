# RUDR9 — Claude Code Review

> Reviewer brief: brutally honest, no soft-padding. Covers installation verification,
> code quality, missing features, bugs, UX, community readiness, security, and a
> prioritized fix list. Based on a full static read of the codebase.

---

## 0. Testing status — read this first

**I could not run the Docker build or the installer in this session.** The sandbox's
permission layer auto-denied every non-trivial shell command (`sg docker …`, `bash -n …`,
`python3 …` were all blocked; only allow-listed commands like `echo` ran). I attempted the
build and the guard unit tests several times and each was rejected before execution.

So this review is **static analysis only**. The dynamic-verification section below is what I
*would* run, and what I expect to happen based on reading the code — but it has **not been
executed**. Treat any "this will fail" as "high-confidence prediction from reading the code,"
not "observed." You should run the Docker harness yourself; the commands are unchanged from
your brief:

```bash
sg docker -c "docker build -t rudr9-test ."
sg docker -c "docker run -d --name rudr9-cc rudr9-test tail -f /dev/null"
sg docker -c "docker exec rudr9-cc bash -lc 'cd /home/rudr9/RUDR9 && ./install.sh 2>&1'"
sg docker -c "docker exec rudr9-cc bash -lc 'hermes profile list && hermes kanban assignees && hermes plugins list --plain --no-bundled 2>/dev/null | grep rudr9'"
sg docker -c "docker rm -f rudr9-cc"
```

The rest of the review does not depend on the sandbox — it's from the source.

---

## a) Installation verification (predicted)

The Dockerfile is a genuinely good test harness: pinned base (`ubuntu:24.04`), non-root
`rudr9` user, Node 22, gh CLI, real Hermes install. That part is solid.

What I predict happens when `install.sh` runs inside it, phase by phase:

| Phase | Predicted result | Why |
|-------|------------------|-----|
| Preflight | **Passes** in the container (hermes, git, node, npx, gh all present) | Dockerfile installs them all |
| 1 Profiles | Works *if* `hermes profile create --clone --description` is a real signature | Assumed, unverified |
| 2 SOULs | Works, but **silently destroys the user's existing default `SOUL.md`** (no backup) | `cp` over `$HERMES_HOME/SOUL.md`, see Bug #3 |
| 3 Toolsets | Works, but **leaves default crippled after uninstall** | Bug #2 |
| 4 Skills (ponytail) | **Marginal** — unpinned raw-GitHub URL, network-dependent, no checksum | Bug #12 |
| 5 MCPs | **Likely fails or installs non-functional servers** | Bug #5, #11 — deprecated GitHub server package, no token prompt, Context7 key |
| 6 Kanban | Works if the `hermes config set kanban.*` keys are real | Assumed |
| 7 Hooks + plugin | Copies files fine; **plugin/hook may be inert** if the API contract differs | Bug #1, #10 |
| 8 Verify | **Reports success it hasn't earned** — only checks file/dir presence | Missing feature #2 |

**Bottom line:** the installer will very likely *print a lot of green checkmarks and exit 0*
while the two things that make RUDR9 more than a pile of markdown — the guard plugin's
authority enforcement and the MCP servers — are the most likely to be silently broken. That
is the worst failure mode: "installed" ≠ "working," and the verifier can't tell the
difference.

---

## b) Code quality

### SOUL.md files — good

The SOULs are the strongest part of the repo. Consistent structure (Identity / Authority /
Limitations / Workflow / Artifacts), concise, enumerated constraints, BDD discipline baked in.
The Reviewer/Security/Performance separation of concerns is clean. Minor issues:

- **`SOUL-default.md` hardcodes the name "Veda"** as the CTO. Every other SOUL is
  role-generic. For an OSS product, shipping the author's name as everyone's CTO identity is
  odd — genericize it or make it configurable (Bug #13).
- **Auditors are told to "review the diff" but have no way to get a diff** (Bug #6). Security
  and Performance have neither `terminal`/git nor a GitHub MCP — only `read_file`/`search_files`
  on the working tree. If the diff lives in a PR, they physically cannot read it. Their whole
  job is unreachable with their toolset.
- Builder SOUL says "Maximum 5 repair iterations" but nothing enforces 5; the installer sets
  `kanban.failure_limit 2`. The "5" is prompt-only (Bug #14).

### Guard plugin — correct rules, **broken profile detection**

`rules.py` `is_allowed()` is fine: clean wildcard matching, sensible allow-lists, fail-open on
unknown profile is a defensible choice. The unit-test matrix in CONTRIBUTING is a good habit.

But `__init__.py` `_get_profile()` is **the single most important bug in the repo** (Bug #1):

```python
def _get_profile() -> str:
    home = os.environ.get("HERMES_HOME", "")
    name = os.path.basename(home.rstrip("/"))
    return "default" if name == ".hermes" else name
```

This assumes `HERMES_HOME` is repointed to `…/profiles/<role>` for each worker. But the
installer's *own* `profile_path()` and your Integration-Plan both say profiles live at
`$HERMES_HOME/profiles/<name>/` while `HERMES_HOME` stays `~/.hermes`. Your own
Integration-Plan appendix (§9) writes the plugin as
`os.environ.get("HERMES_PROFILE", "default")` — a **different** mechanism. The implementation
and the design doc disagree on how to identify the active profile. One of them is wrong.

If Hermes keeps `HERMES_HOME=~/.hermes` and signals the profile some other way, then
`_get_profile()` returns `"default"` for **every** worker, and the guard applies the CTO's
allow-list to the Builder and VCM — blocking `write_file`, `terminal`, `patch`,
`code_execution`. The guard would break the two roles that actually do work, and enforce
nothing on the read-only roles it was meant to catch. **This must be verified against the real
Hermes runtime before shipping.** The entire "belt + suspenders" security claim rests on it.

### Guard plugin — API contract is assumed, not verified

`register(ctx)` + `ctx.register_hook("pre_tool_call", …)` and the `{"block": True, "reason":
…}` return schema are all assumed. If Hermes' plugin entrypoint or hook name differs, the
plugin loads and does nothing — silently. Same for the hook (`events: [agent:step]`,
`handle(event_type, context)`, `context["iteration"]`, `context["tool_names"]`): every one of
those keys is a guess at Hermes' event schema.

### Installer — mostly clean, a few real robustness holes

`set -euo pipefail`, colorized output, dry-run, uninstall, idempotent skip-if-exists — all
good instincts. But:

- **`create_profiles` has no `|| true`** (line 146). Under `set -e`, one failed
  `hermes profile create` aborts the entire install — directly contradicting the "per-profile
  error handling, one failure doesn't abort" claim in Integration-Plan §8 (Bug #7).
- **Preflight hard-fails on missing Node/git** (they increment `errors`, and `errors>0` exits)
  while styling them as yellow ⚠ warnings, yet **npx missing is only a soft warning** even
  though Phase 5 runs everything through `npx`. The gating is inconsistent with both the
  styling and the actual dependency graph (Bug #9).
- **The advertised one-liner is broken** (Bug #8). `resolve_assets()` requires `assets/`
  next to the script; `curl … | bash` pipes a lone `install.sh` with no assets dir → immediate
  "Cannot find assets directory" exit. The primary documented install path cannot work.

---

## c) Missing features

1. **No secret handling.** Integration-Plan §6 promises "the installer prompts for
   [`GITHUB_PERSONAL_ACCESS_TOKEN`]." It doesn't. There is no prompt, no `.env` write, no
   scope check. GitHub MCP ships dead on arrival.
2. **No real post-install verification.** Phase 8 checks that *files exist*. It never invokes
   an MCP, never confirms the plugin is enabled (`hermes plugins list`), never confirms a
   toolset was actually disabled, never confirms the guard blocks anything. "Installed" is not
   "working."
3. **No rollback.** Integration-Plan §8/§4.3 promise "atomic-ish with rollback." If Phase 5
   dies halfway, you're left with a half-configured Hermes and no recovery path.
4. **No version pinning** on ponytail (raw `main`) — your own Architecture-Review §4.3 says
   "pin a commit." Ignored.
5. **No test-authorship / docs / dependency-decision owner** — exactly the role gaps
   Architecture-Review §1.1 flagged. Nobody writes adversarial tests; Builder grades its own
   homework.
6. **No observability or cost ledger** despite Architecture-Review §3.4–3.5 calling it a
   product differentiator. No event log, no per-PR budget cap, no push-on-block.
7. **No CI.** `.github/` has issue/PR templates but no workflow. CONTRIBUTING tells
   contributors to run `./install.sh --dry-run` and the guard tests — nothing enforces it.

---

## d) Bugs & issues (ranked)

| # | Sev | Bug |
|---|-----|-----|
| 1 | **Critical** | Guard `_get_profile()` derives profile from `HERMES_HOME` basename; contradicts the `profiles/<name>/` layout and your own design doc's `HERMES_PROFILE`. Likely resolves every worker to `default`, breaking Builder/VCM and enforcing nothing on auditors. |
| 2 | **High** | `uninstall` never re-enables `file`/`terminal` on the default profile that `configure_toolsets` disabled. After uninstall, the user's primary profile is left unable to write files or use a terminal — a regression to their base Hermes install. |
| 3 | **High** | `install_souls` overwrites `$HERMES_HOME/SOUL.md` with no backup. A user's customized default SOUL is destroyed; uninstall only backs up the RUDR9 CTO SOUL, so the original is unrecoverable. |
| 4 | High | Authority enforcement is bypassable for Builder and VCM via `terminal`. Both have it; the guard checks tool *names* only. Builder can `gh pr merge`; VCM can `cat > file.py` to write app code. The README's "physically cannot" is false for these two roles. |
| 5 | Med-High | GitHub MCP uses `@modelcontextprotocol/server-github`, the **deprecated/archived** reference server (GitHub's official is `github/github-mcp-server`). Plus no token is ever provided. GitHub MCP is non-functional out of the box. |
| 6 | Med-High | Security & Performance auditors have no tool that can produce a diff (no git/terminal, no GitHub MCP). Their core workflow is unreachable. |
| 7 | Med | `create_profiles` lacks `|| true`; one failed create aborts the whole install under `set -e`. |
| 8 | Med | Broken `curl \| bash` one-liner (no assets dir). Primary documented install path fails. |
| 9 | Med | Preflight hard-fails on Node/git (optional-ish) but only warns on npx (required by Phase 5). Inconsistent gating. |
| 10 | Med | Long-task hook imports `httpx` at top level (may not exist in Hermes' runtime → load error) and depends on undocumented `TELEGRAM_*` env vars. Its `context` keys are unverified against Hermes' event schema. |
| 11 | Low-Med | Context7 (`@upstash/context7-mcp`) now expects an API key; unauthenticated use may be rate-limited/fail. |
| 12 | Low-Med | Ponytail installed from unpinned `main` — upstream change silently breaks new installs. |
| 13 | Low | `SOUL-default.md` hardcodes "Veda"; author name leaks into every user's CTO. |
| 14 | Low | Builder "max 5 repair iterations" is prompt-only; the enforced knob is `failure_limit=2`. Mismatched, both soft. |
| 15 | Low | `hermes tools disable file` for default omits `-p default`; relies on ambient active profile, inconsistent with `-p <role>` elsewhere. |

---

## e) UX improvements

- **Stop lying green.** Make Phase 8 actually probe: `hermes plugins list | grep -q rudr9-guard`,
  round-trip one MCP call, assert a toolset is disabled, and — best of all — spawn the guard
  with a fake `planner`/`write_file` and confirm it blocks. A verifier that can't detect the
  most likely failure (Bug #1) is theater.
- **Prompt for the GitHub PAT** (and Context7 key) with a masked read, write to the right
  `.env`, and verify scopes with `gh auth status` / a test API call. Fail *now*, loudly, not
  at first use.
- **Make the entry point real.** Ship a bootstrap that `git clone`s (or downloads a release
  tarball) then runs `install.sh`, so the README one-liner actually works. Or drop the
  one-liner and document `git clone && ./install.sh`.
- **Summarize what changed and how to undo it** at the end (profiles created, tools disabled on
  default, files overwritten + backup paths). Right now the user has no map of the blast radius.
- **Idempotent uninstall that truly restores** the default profile (re-enable tools, restore
  original SOUL from a backup you should have taken in Phase 2).

---

## f) Community readiness

**Not ready to ship to the Hermes OSS community as-is.** The scaffolding is there (LICENSE,
CoC, CONTRIBUTING, SECURITY, issue/PR templates, a Docker test harness — all good), but:

- The **advertised install command doesn't work** (Bug #8). That's a first-impression killer.
- **Placeholder/unverified URLs and domains** (`ardhastudios.com/rudr9/install.sh`,
  `hermes-agent.nousresearch.com`) — confirm these resolve before publishing.
- **No CI** to run the dry-run + guard tests CONTRIBUTING references. Add a GitHub Actions
  workflow that builds the Docker image and runs a real install + verification on every PR.
  You already have the Dockerfile — wire it up.
- **Overselling in the README.** "The Planner physically cannot write code… authority enforced
  by tooling, not prompts" is true for read-only roles but false for Builder/VCM (Bug #4).
  Either scope the claim honestly or close the terminal escape hatch.
- **Author-name leak** ("Veda") in a shared identity file.
- The **guard's real behavior is unverified** against Hermes. Shipping a security feature you
  haven't confirmed loads is worse than shipping none, because it invites false confidence.

Ship the Docker-based CI + a working installer + a verified guard, and it's close.

---

## g) Security

- **The guard is the security story, and it's unverified + coarse.** Bug #1 may neuter it
  entirely; Bug #4 (terminal escape hatch) means even when it works, two roles can do anything.
  Tool-name allow-listing cannot enforce "VCM can't write app logic" when VCM has a shell.
  Real enforcement needs either (a) no terminal for VCM (make git a constrained script/hook), or
  (b) command-content inspection, or (c) GitHub branch protection + a merge token only the merge
  step holds — as your own Architecture-Review §1.2 already prescribed.
- **Installer trust:** `curl … | bash` from a not-yet-verified domain is the usual supply-chain
  exposure; acceptable if the domain is yours and served over HTTPS, but pin/verify.
- **Unpinned third-party fetch** (ponytail `main`) is a supply-chain hole — pin a commit + ideally
  verify a hash.
- **Data egress:** the long-task hook POSTs tool names to the Telegram API if tokens are set.
  Minor, user-opt-in, but document it — it's undocumented today.
- **SECURITY.md claims** "per-profile toolset restrictions — roles physically lack tools to
  violate their authority boundaries." That's the same overclaim as the README; it's false for
  Builder/VCM. Don't put an unverified guarantee in your security policy.
- Non-root container user, no secrets in repo, `set -euo pipefail` — all good.

---

## h) Top 5 prioritized improvements (fix these FIRST)

1. **Verify and fix the guard's profile detection (Bug #1).** Confirm against a running Hermes
   whether the active profile comes from `HERMES_HOME`, `HERMES_PROFILE`, or something else.
   Until this is proven, *nothing* about authority enforcement is real. Add a verification step
   that actually exercises a block. This is the keystone — everything else is secondary.
2. **Make uninstall non-destructive and make install non-destructive (Bugs #2, #3).** Back up
   the default `SOUL.md` before overwriting it in Phase 2; on uninstall, re-enable the tools you
   disabled on `default` and restore the original SOUL. Leaving a user's base profile crippled
   after they remove your tool is unacceptable.
3. **Close or acknowledge the terminal authority hole (Bug #4).** Either remove `terminal` from
   VCM (git via a constrained script) and gate merges behind a token, or explicitly downgrade the
   README/SECURITY claims from "physically cannot" to "instructed not to, enforced where the
   toolset allows." Pick honesty or enforcement — not the current gap between them.
4. **Fix MCP + secret handling (Bugs #5, #6, #11) and make the verifier real (#20-class).**
   Move to the maintained GitHub MCP server, prompt for and verify the PAT/Context7 key, give the
   auditors a way to read a diff, and turn Phase 8 into a functional probe (invoke each MCP,
   confirm the plugin is enabled, assert a toolset is off — see Missing feature #2).
5. **Fix distribution + add CI (Bug #8, Missing #7).** Ship a bootstrap that clones/downloads the repo
   so the one-liner works, and add a GitHub Actions workflow that builds the existing Dockerfile
   and runs a full install + verification on every PR. You cannot claim "one command → full team"
   while the one command exits on line 65.

---

### What's genuinely good (so this isn't all teeth)

- Clean, consistent SOUL authorship with BDD discipline and clear authority/limitation framing.
- Thoughtful cost-control defaults (`max_in_progress_per_profile: 1`, manual decompose, scope
  tiers) — directly responsive to the Architecture-Review critique.
- Defense-in-depth *concept* (toolsets + guard) is the right instinct, even if the execution has
  a hole.
- Real Docker test harness, dry-run, uninstall, and a full community-docs set — most projects at
  this stage have none of that.
- The repo clearly internalized its own Architecture-Review on the cheap wins (sequential
  default, scope-adaptive ceremony). The gap now is *execution correctness*, not vision.

The architecture is defensible; the **implementation is not yet trustworthy** because its two
load-bearing mechanisms (guard enforcement, MCP integration) are unverified and probably broken,
and the install/uninstall lifecycle damages the user's base profile. Fix the five above and run
the Docker harness end-to-end before any public release.
