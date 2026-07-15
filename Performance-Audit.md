# RUDR9 Installer — Performance Audit

> Target: `install.sh`. Goal: cut the ~8-minute install to well under 1 minute
> **without changing what ends up installed**. All timings below are the
> worst-case attributable cost; code snippets are drop-in.

---

## 1. Where the 8 minutes actually goes

Measured/attributable breakdown of a clean install (`main()` order:
`create_profiles → install_souls → configure_toolsets → install_skills →
install_mcps → …`):

| Phase | What runs | Invocations | ~Cost | Class |
|-------|-----------|-------------|-------|-------|
| 1 create_profiles | `hermes profile create --clone` | 7 (+7 `list`) | ~10–20 s | CLI startup |
| 2 install_souls | `cp` | 0 hermes | <1 s | fine |
| 3 configure_toolsets | `hermes … tools disable` | 13 | ~15–25 s | CLI startup |
| 4 install_skills | **`skills install <url>` → download + threat scan, per profile** | **8** | **~240 s** | **BOTTLENECK** |
| 5 install_mcps | **`mcp add … --connect-timeout 90` → npx fetch + connect + tool probe** | **5** | **~270 s** | **BOTTLENECK** |
| 6 setup_kanban | `kanban init` + 6 `config set` | 7 | ~8 s | CLI startup |
| 7 hooks+plugin | `cp -r` + `plugins enable` | 3 | ~3 s | fine |
| 8 verify | many `list` calls | ~15 | ~15 s | CLI startup |

**~510 s (8.5 min) is Phases 4 + 5.** Everything else combined is ~1 min of
CLI-process-startup overhead. So the audit priority is unambiguous:

1. **Ponytail: stop scanning it 8 times** (~240 s → ~30 s → **~0 s**).
2. **MCP: stop probing servers at install time** (~270 s → **~0 s**).
3. Collapse the remaining CLI-startup churn (Phases 1/3/8).

---

## 2. Bottleneck 1 — Ponytail installed + security-scanned per profile

### What's slow
`install_skills()` (install.sh:245-255) loops over `default` + 7 roles and calls:

```bash
hermes -p "$role" skills install "$ponytail_url" --yes
```

Each call re-downloads `SKILL.md` **and** re-runs the Hermes threat-pattern scan
(the same scan `AGENTS.md` passes through — Integration-Plan.md:274). 8 × ~30 s ≈ **4 min**.

### Is it inherent? No.
The scanned artifact is **byte-identical** for every profile. Scanning it 8 times
is pure waste. Worse: the script clones profiles in Phase 1 *before* this phase,
so it deliberately throws away the one mechanism that would make this free.

### Fix 1a (primary) — seed `default`, then let `--clone` inherit it

`hermes profile create --clone` "inherits config, .env, SOUL.md, **skills**"
(Integration-Plan.md:14-35). So install ponytail into `default` **once** (one
scan), and clone *after* that. All 7 clones inherit ponytail for free.

This requires reordering `main()`: seed default → clone → configure. New phase:

```bash
# NEW Phase 0.5 — seed universal assets into default BEFORE cloning
seed_default() {
  echo -e "${CYAN}${BOLD}Seeding default profile (pre-clone)${NC}"
  [ "$DRY_RUN" = true ] && { echo "  [dry-run] install ponytail to default once"; return; }

  local ponytail_url="https://raw.githubusercontent.com/DietrichGebert/ponytail/main/skills/ponytail/SKILL.md"
  if hermes -p default skills list 2>/dev/null | grep -qw ponytail; then
    echo -e "  ${YELLOW}⊘ default: ponytail already present${NC}"
  else
    hermes -p default skills install "$ponytail_url" --yes 2>/dev/null \
      && echo -e "  ${GREEN}✓ default: ponytail installed (single scan)${NC}" \
      || echo -e "  ${YELLOW}⚠ default: ponytail install failed${NC}"
  fi
}
```

`main()` becomes: `preflight → seed_default → create_profiles → install_souls → …`
and `install_skills()` is **deleted entirely** (or reduced to the reconcile step below).

- **Saves:** 7 scans × ~30 s ≈ **~210 s**.
- **Risk:** clones must be created *after* the seed. On a re-run, profiles that
  already exist won't re-clone and so won't pick up a freshly-seeded skill — handle
  with the reconcile step (Fix 1b). Also confirm `--clone` deep-copies `skills/`
  (documented, but verify once — see §6).

### Fix 1b (reconcile / idempotent re-runs) — copy the skill dir, no scan

For profiles that already exist (re-run) or if you keep them created before seeding,
copy the already-scanned skill directory straight into each profile. A filesystem
copy triggers **no download and no scan**:

```bash
reconcile_ponytail() {
  local src; src="$(profile_path default)/skills/ponytail"
  [ -d "$src" ] || return 0
  for role in "${PROFILES[@]}"; do
    local dst; dst="$(profile_path "$role")/skills/ponytail"
    if [ ! -d "$dst" ]; then
      cp -r "$src" "$dst" && echo -e "  ${GREEN}✓ $role: ponytail copied (no scan)${NC}"
    fi
  done
}
```

- **Saves:** same ~210 s, and works even when profiles pre-exist.
- **Risk:** assumes skills are per-profile at `profiles/<n>/skills/` (documented,
  Integration-Plan.md:31) and that Hermes doesn't keep a separate per-profile skill
  *registry/index* that a bare `cp` would miss. If it does, the copied skill may not
  show in `skills list` until re-indexed. **Verify** (§6). Prefer Fix 1a where clone
  uses Hermes's own mechanism and can't desync an index.

### On symlinks (the question asked)
**Don't symlink; copy or clone.** Symlinking `profiles/<n>/skills/ponytail ->
~/.hermes/skills/ponytail` is fragile for three reasons:
1. `--uninstall` / `hermes … skills gc` may `rm -rf` through the link and destroy
   the shared target for every profile at once.
2. The threat scanner may re-scan on load (defeating the point) or reject non-regular
   files.
3. A per-profile skill index (if it exists) won't be populated by a bare symlink.

If skills turn out to be **global** (single `~/.hermes/skills/`, profiles reference it),
then you install ponytail **once, globally, with no `-p`** and do nothing per-profile —
even better than clone. That is the first thing to check in §6.

---

## 3. Bottleneck 2 — MCP servers probed at install time (the 90 s hang)

### What's slow
`install_mcps()` (install.sh:273-292) calls `hermes mcp add` 5 times
(context7 ×2, github ×3), each with `--connect-timeout 90`:

```bash
echo "y" | hermes -p "$role" mcp add github --command "npx" \
  --args "-y @modelcontextprotocol/server-github" --connect-timeout 90
```

`mcp add` does three expensive things: (1) `npx -y` **downloads** the package on first
run, (2) **launches** the server, (3) **connects and probes its tool list**. For GitHub,
there is no `GITHUB_PERSONAL_ACCESS_TOKEN` yet at install time (the script itself warns the
user to add one later — install.sh:290), so the connection **cannot succeed** and burns the
**full 90 s timeout**. 3 × 90 s = **270 s of pure dead-wait**, plus context7 fetch/probe.

### Is it inherent? No — the probe has zero value here.
You are configuring servers, not using them. Hermes launches an MCP server lazily when an
agent first calls it. The install-time connect/probe proves nothing (github literally can't
authenticate yet) and is the single largest fixed cost in the script.

### Fix 2a (primary) — write `mcp_servers` into `config.yaml` directly

The MCP schema is a plain `config.yaml` block (Integration-Plan.md:331-337). Write it;
skip the probe entirely.

```bash
# Prefer yq if available (correct, idempotent). Requires: yq v4+.
write_mcp_yq() {                      # role name pkg
  local cfg; cfg="$(profile_path "$1")/config.yaml"
  yq -i ".mcp_servers.$2.command = \"npx\"
       | .mcp_servers.$2.args = [\"-y\", \"$3\"]" "$cfg"
}

# Fallback if yq is absent: guarded append (idempotent via grep).
write_mcp_append() {                  # role name pkg
  local cfg; cfg="$(profile_path "$1")/config.yaml"
  grep -qE "^[[:space:]]+$2:" "$cfg" 2>/dev/null && return 0   # already present
  grep -q '^mcp_servers:' "$cfg" 2>/dev/null || echo 'mcp_servers:' >> "$cfg"
  cat >> "$cfg" <<EOF
  $2:
    command: "npx"
    args: ["-y", "$3"]
EOF
}

install_mcps() {
  echo -e "${CYAN}${BOLD}Phase 5: Configuring MCP servers (no probe)${NC}"
  [ "$DRY_RUN" = true ] && { echo "  [dry-run] write context7 + github to config.yaml"; return; }
  local w; command -v yq >/dev/null 2>&1 && w=write_mcp_yq || w=write_mcp_append
  for role in architect builder; do "$w" "$role" context7 "@upstash/context7-mcp"; done
  for role in default vcm reviewer; do "$w" "$role" github "@modelcontextprotocol/server-github"; done
  echo -e "  ${GREEN}✓ MCP servers written to config (launch lazily on first use)${NC}\n"
}
```

- **Saves:** eliminates all 5 probes incl. the 3 × 90 s github hangs → **~270 s**.
- **Risk:** the `config.yaml` MCP schema must match exactly what Hermes expects
  (key name, `command`/`args` shape). The `yq` path is safe and idempotent; the raw
  `append` fallback assumes `mcp_servers:` is either absent or the last top-level block —
  if Hermes writes other content after it, the appended block lands under the wrong parent.
  **Confirm the schema against one real `hermes mcp add`-generated `config.yaml`** (§6).
  Also: the npx package is no longer pre-fetched, so the *first* real use pays the
  one-time download. That's the right place for it (lazy, once, when actually needed),
  not ×5 at install.

### Fix 2b (low-risk fallback, if you must keep `mcp add`)
If writing YAML is deemed too risky, at minimum stop the 90 s hangs:

```bash
--connect-timeout 5     # was 90
```

The github probe still fails (no token), but in 5 s not 90 s. 5 × 5 s ≈ 25 s vs 270 s.
Keep this as the conservative option; Fix 2a is strictly better.

---

## 4. Bottleneck 3 — sequential CLI-startup churn (Phases 1, 3, 8)

After Fixes 1–2, the remaining time is ~25 processes each paying Hermes CLI startup.
Two cheap collapses:

### Fix 3a — write toolset restrictions to `config.yaml` instead of 13 `tools disable`

`configure_toolsets()` (install.sh:200-228) spawns Hermes 13 times to toggle flags that
are just entries in `config.yaml`. Write them directly:

```bash
set_disabled() {                       # role  "file,terminal"
  local cfg; cfg="$(profile_path "$1")/config.yaml"
  if command -v yq >/dev/null 2>&1; then
    yq -i ".tools.disabled = [\"${2//,/\",\"}\"]" "$cfg"
  else
    grep -q '^tools:' "$cfg" || printf 'tools:\n  disabled: [%s]\n' \
      "\"${2//,/\", \"}\"" >> "$cfg"
  fi
}
configure_toolsets() {
  [ "$DRY_RUN" = true ] && { echo "  [dry-run] restrict toolsets"; return; }
  set_disabled default     "file,terminal"
  set_disabled planner     "file,terminal"
  set_disabled architect   "file,terminal"
  set_disabled vcm         "file"
  set_disabled security    "file,terminal"
  set_disabled performance "file,terminal"
  set_disabled reviewer    "file,terminal"
  # builder: no restrictions
}
```

- **Saves:** ~13 process starts → ~15–25 s.
- **Risk:** must match the `tools.disabled` key Hermes reads (Notes.md:422 shows
  `hermes tools enable/disable`; confirm it maps to `tools.disabled` in YAML — §6).
  If unsure, keep the CLI calls but **batch per profile** if the CLI accepts multiple
  (`hermes -p planner tools disable file terminal`) — halves the invocations.

### Fix 3b — profile creation: keep `--clone`, don't `cp -r` the dir

Answering the question directly: **`hermes profile create --clone` is the right call; do
NOT clone-one-then-`cp -r`-the-rest.** A raw directory copy won't register the profile in
Hermes's profile registry (the same reason `skills list` may not see a copied skill), and
each profile needs a distinct `--description` for the Kanban auto-decomposer
(Integration-Plan.md:24). The 7 clones cost ~10–20 s total — not worth the correctness risk.

If you want to shave that, parallelize the clones **only if** profile-registry writes are
atomic (verify first — concurrent writes to a shared `profiles` index can corrupt it):

```bash
for role in "${PROFILES[@]}"; do
  hermes profile create "$role" --clone --description "${DESCRIPTIONS[$role]}" \
    >/dev/null 2>&1 &
done
wait     # note: with `set -e`, guard failures — see §7
```

- **Saves:** ~10 s (marginal). **Recommendation:** leave clones sequential unless §6
  confirms the registry is safe under concurrency. This is the lowest-value change.

### Fix 3c — the general principle
After Fixes 1a + 2a, the per-profile post-clone work (SOUL `cp`, toolset write, MCP
write) is **all local filesystem, sub-second**. The parallelization the ticket asks about
("skill install + toolset in parallel per-profile") stops being necessary — you can't
meaningfully parallelize work that's already ~0 s. Parallelism only mattered because each
step was doing network I/O; remove the I/O and the need for parallelism evaporates. Ship
the sequential version; it's simpler and already fast.

---

## 5. Recommended install order (rewritten `main`)

```bash
main() {
  parse_args "$@"; resolve_assets
  [ "$UNINSTALL" = true ] && { uninstall; exit 0; }

  preflight
  seed_default          # NEW: install ponytail into default ONCE (1 scan)
  create_profiles       # clone AFTER seed → all inherit ponytail
  reconcile_ponytail    # NEW: copy skill into any pre-existing profiles (re-run safety)
  install_souls         # cp (already fast)
  configure_toolsets    # NEW: direct config.yaml writes (Fix 3a)
  install_mcps          # NEW: direct config.yaml writes, no probe (Fix 2a)
  setup_kanban
  install_hooks_and_plugin
  verify_install
  init_project
}
```

`install_skills()` is removed (folded into `seed_default` + `reconcile_ponytail`).

---

## 6. Verify against a real Hermes before shipping (do not assume)

The fixes rest on Hermes internals documented in `Integration-Plan.md` but not proven
against a live install. Confirm each with one throwaway install:

1. **Does `--clone` deep-copy `profiles/<n>/skills/`?** Clone default (with ponytail),
   run `hermes -p <clone> skills list`, expect `ponytail`. → validates Fix 1a.
2. **Are skills per-profile or global?** `ls ~/.hermes/skills` vs
   `ls ~/.hermes/profiles/planner/skills`. If global, ponytail installs once with no `-p`
   and §2 gets even simpler.
3. **Is there a per-profile skill index** that a bare `cp` would bypass? Copy ponytail
   into a profile, run `skills list`. If it doesn't appear, prefer Fix 1a over 1b.
4. **Exact `config.yaml` MCP schema:** run one `hermes mcp add`, diff the resulting
   `config.yaml`. Match `write_mcp_*` to it (key name, quoting of `args`). → validates Fix 2a.
5. **Toolset YAML key:** run `hermes -p x tools disable file`, inspect `config.yaml`.
   Confirm it's `tools.disabled: [file]`. → validates Fix 3a.
6. **Registry concurrency:** only if adopting parallel clones — check whether
   `hermes profile create` writes a shared index; if yes, keep clones sequential.

If any of 1/3/4/5 fails, fall back to the CLI form of that specific fix (2b for MCP,
batched `tools disable` for toolsets) — you still keep the big win (ponytail-via-clone)
and the 90 s→5 s timeout cut.

---

## 7. Risks & tradeoffs summary

| Fix | Saves | Primary risk | Mitigation |
|-----|-------|--------------|------------|
| 1a ponytail via clone | ~210 s | clones must post-date the seed; re-runs miss it | reorder `main`; add `reconcile_ponytail` (1b) |
| 1b copy skill dir | ~210 s | per-profile skill index may not see a raw `cp` | verify §6.3; else use 1a only |
| 2a MCP → config.yaml | ~270 s | YAML schema mismatch; append lands under wrong parent | use `yq`; verify §6.4; fallback 2b |
| 2b timeout 90→5 | ~245 s | github still can't auth (unchanged behavior) | none needed; conservative option |
| 3a toolsets → config | ~20 s | wrong `tools.disabled` key | verify §6.5; else batch CLI calls |
| 3b parallel clones | ~10 s | registry corruption under concurrency | skip unless §6.6 confirms atomic |

### `set -euo pipefail` interaction (important)
The script sets `-e`. Two of the fixes need care:
- **Backgrounded jobs + `wait`:** with `set -e`, a non-zero `wait` aborts the script.
  If you parallelize, use `wait || true` or collect PIDs and check individually, mirroring
  the existing `… || true` idiom (install.sh:146, :201).
- **`grep` in guards:** `grep -q … && return 0` returning non-zero (no match) is fine, but
  `grep …; if …` patterns under `-e` can abort — keep guards as `grep -q … || <do work>`.

---

## 8. Projected result

| | Before | After (Fixes 1a + 2a + 3a) |
|---|--------|-----------------------------|
| Ponytail | ~240 s (8 scans) | ~30 s (1 scan) |
| MCP | ~270 s (5 probes, 3×90 s hang) | ~0 s (config writes) |
| Toolsets | ~20 s (13 procs) | ~1 s (YAML writes) |
| Clone + rest | ~40 s | ~40 s |
| **Total** | **~8.5 min** | **~1.2 min** |

The single most valuable line of the whole audit: **move the ponytail install ahead of
the clone, and stop probing MCP servers you can't authenticate yet.** Those two changes
alone take ~510 s → ~30 s. Everything else is polish.
