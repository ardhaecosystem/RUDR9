#!/bin/bash
# ============================================================================
# RUDR9 Installer
# ============================================================================
# Transforms a fresh Hermes Agent installation into a 9-role AI engineering
# organization. One command → full dev team operational.
#
# Usage:
#   ./install.sh                 # full install
#   ./install.sh --with-project  # also init .rudr9/ in current dir
#   ./install.sh --uninstall     # remove all RUDR9 profiles + artifacts
#   ./install.sh --dry-run       # show what would happen, change nothing
#
# ============================================================================

set -euo pipefail

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- Config ---
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
ASSETS_DIR=""  # resolved below
DRY_RUN=false
WITH_PROJECT=false
UNINSTALL=false

# Profile descriptions (used by Kanban auto-decomposer for routing)
declare -A DESCRIPTIONS=(
  [planner]="Transforms requirements into engineering specifications with BDD acceptance criteria. Cannot write code."
  [architect]="Designs technical solutions, API contracts, system structure. Cannot implement or commit code."
  [vcm]="Owns Git workflow, branches, PRs, merges. Follows open-source GitHub Flow. Cannot write application logic."
  [builder]="Implements approved specifications and runs inline validation. Cannot change requirements or merge PRs."
  [security]="Reviews PRs for security vulnerabilities and secure coding practices. Cannot modify implementation."
  [performance]="Evaluates runtime efficiency, scalability, and resource utilization. Cannot rewrite implementation."
  [reviewer]="Final engineering quality gate before merge. Reviews spec, architecture, implementation, security, performance. Cannot edit code."
)

PROFILES=(planner architect vcm builder security performance reviewer)

# Profile path helper
profile_path() {
  if [ "$1" = "default" ]; then
    echo "$HERMES_HOME"
  else
    echo "$HERMES_HOME/profiles/$1"
  fi
}

# Resolve assets dir (directory containing this script)
resolve_assets() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # If running from repo, assets are alongside the script
  if [ -d "$script_dir/assets" ]; then
    ASSETS_DIR="$script_dir/assets"
  elif [ -d "$script_dir/../assets" ]; then
    ASSETS_DIR="$script_dir/../assets"
  else
    echo -e "${RED}Cannot find assets directory. Expected at $script_dir/assets or $script_dir/../assets${NC}"
    exit 1
  fi
}

# ============================================================================
# Preflight
# ============================================================================

preflight() {
  echo -e "${CYAN}${BOLD}RUDR9 Installer — Preflight Checks${NC}"
  echo ""

  local errors=0

  # Hermes installed?
  if ! command -v hermes &>/dev/null; then
    echo -e "  ${RED}✗ Hermes Agent not found. Install it first:${NC}"
    echo -e "    curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash"
    errors=$((errors + 1))
  else
    echo -e "  ${GREEN}✓ Hermes Agent: $(hermes --version 2>/dev/null || echo 'installed')${NC}"
  fi

  # Git available?
  if ! command -v git &>/dev/null; then
    echo -e "  ${YELLOW}⚠ Git not found (VCM role needs it)${NC}"
    errors=$((errors + 1))
  else
    echo -e "  ${GREEN}✓ Git: $(git --version)${NC}"
  fi

  # Node available? (for MCP servers)
  if ! command -v node &>/dev/null; then
    echo -e "  ${YELLOW}⚠ Node.js not found (Context7 MCP needs it)${NC}"
    errors=$((errors + 1))
  else
    echo -e "  ${GREEN}✓ Node.js: $(node --version)${NC}"
  fi

  # npx available? (MCP servers run via npx)
  if ! command -v npx &>/dev/null; then
    echo -e "  ${YELLOW}⚠ npx not found (MCP servers need it)${NC}"
  else
    echo -e "  ${GREEN}✓ npx available${NC}"
  fi

  # GitHub auth? (optional but recommended for VCM)
  if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
    echo -e "  ${GREEN}✓ GitHub CLI authenticated${NC}"
  else
    echo -e "  ${YELLOW}⚠ GitHub CLI not authenticated (VCM will need a PAT in .env)${NC}"
  fi

  echo ""

  if [ $errors -gt 0 ]; then
    echo -e "${RED}Preflight failed with $errors error(s). Fix above issues and re-run.${NC}"
    exit 1
  fi

  echo -e "${GREEN}Preflight passed.${NC}"
  echo ""
}

# ============================================================================
# Phase 1: Profile Creation
# ============================================================================

create_profiles() {
  echo -e "${CYAN}${BOLD}Phase 1: Creating profiles${NC}"

  if [ "$DRY_RUN" = true ]; then
    echo "  [dry-run] Would create ${#PROFILES[@]} profiles"
    return
  fi

  for role in "${PROFILES[@]}"; do
    if hermes profile list 2>/dev/null | grep -qw "$role"; then
      echo -e "  ${YELLOW}⊘ $role already exists, skipping${NC}"
    else
      hermes profile create "$role" --clone --description "${DESCRIPTIONS[$role]}" 2>/dev/null
      echo -e "  ${GREEN}✓ Created profile: $role${NC}"
    fi
  done

  echo -e "  ${GREEN}✓ Default profile becomes CTO (modified in-place)${NC}"
  echo ""
}

# ============================================================================
# Phase 2: SOUL.md Installation
# ============================================================================

install_souls() {
  echo -e "${CYAN}${BOLD}Phase 2: Installing SOUL.md files${NC}"

  if [ "$DRY_RUN" = true ]; then
    echo "  [dry-run] Would write SOUL.md to 8 profiles"
    return
  fi

  for role in default "${PROFILES[@]}"; do
    local soul_src="$ASSETS_DIR/souls/SOUL-$role.md"
    local soul_dst="$(profile_path "$role")/SOUL.md"

    if [ ! -f "$soul_src" ]; then
      echo -e "  ${RED}✗ Missing SOUL template: $soul_src${NC}"
      continue
    fi

    cp "$soul_src" "$soul_dst"
    echo -e "  ${GREEN}✓ SOUL.md → $role${NC}"
  done

  echo ""
}

# ============================================================================
# Phase 3: Toolset Configuration
# ============================================================================

configure_toolsets() {
  echo -e "${CYAN}${BOLD}Phase 3: Configuring per-profile toolsets${NC}"

  if [ "$DRY_RUN" = true ]; then
    echo "  [dry-run] Would restrict toolsets per profile"
    return
  fi

  # Default (CTO): no file write, no terminal — router only
  hermes tools disable file 2>/dev/null && echo -e "  ${GREEN}✓ default: file disabled${NC}" || true
  hermes tools disable terminal 2>/dev/null && echo -e "  ${GREEN}✓ default: terminal disabled${NC}" || true

  # Planner: no terminal, no file
  hermes -p planner tools disable terminal 2>/dev/null && echo -e "  ${GREEN}✓ planner: terminal disabled${NC}" || true
  hermes -p planner tools disable file 2>/dev/null && echo -e "  ${GREEN}✓ planner: file disabled${NC}" || true

  # Architect: no terminal, no file write (read is via search_files)
  hermes -p architect tools disable terminal 2>/dev/null && echo -e "  ${GREEN}✓ architect: terminal disabled${NC}" || true
  hermes -p architect tools disable file 2>/dev/null && echo -e "  ${GREEN}✓ architect: file disabled${NC}" || true

  # VCM: terminal enabled (git ops), file disabled
  hermes -p vcm tools disable file 2>/dev/null && echo -e "  ${GREEN}✓ vcm: file disabled${NC}" || true

  # Builder: terminal + file + code_execution enabled (no restrictions beyond defaults)
  echo -e "  ${GREEN}✓ builder: full implementation tools${NC}"

  # Security: read-only
  hermes -p security tools disable terminal 2>/dev/null && echo -e "  ${GREEN}✓ security: terminal disabled${NC}" || true
  hermes -p security tools disable file 2>/dev/null && echo -e "  ${GREEN}✓ security: file disabled${NC}" || true

  # Performance: read-only (code_execution for benchmarks)
  hermes -p performance tools disable terminal 2>/dev/null && echo -e "  ${GREEN}✓ performance: terminal disabled${NC}" || true
  hermes -p performance tools disable file 2>/dev/null && echo -e "  ${GREEN}✓ performance: file disabled${NC}" || true

  # Reviewer: read-only
  hermes -p reviewer tools disable terminal 2>/dev/null && echo -e "  ${GREEN}✓ reviewer: terminal disabled${NC}" || true
  hermes -p reviewer tools disable file 2>/dev/null && echo -e "  ${GREEN}✓ reviewer: file disabled${NC}" || true

  echo ""
}

# ============================================================================
# Phase 4: Skill Installation
# ============================================================================

install_skills() {
  echo -e "${CYAN}${BOLD}Phase 4: Installing skills${NC}"

  if [ "$DRY_RUN" = true ]; then
    echo "  [dry-run] Would install ponytail to all profiles"
    return
  fi

  # Ponytail to all profiles
  local ponytail_url="github.com/DietrichGebert/ponytail"
  for role in default "${PROFILES[@]}"; do
    if hermes -p "$role" skills list 2>/dev/null | grep -qw "ponytail"; then
      echo -e "  ${YELLOW}⊘ $role: ponytail already installed${NC}"
    else
      hermes -p "$role" skills install "$ponytail_url" --enable 2>/dev/null && \
        echo -e "  ${GREEN}✓ $role: ponytail installed${NC}" || \
        echo -e "  ${YELLOW}⚠ $role: ponytail install failed (manual: hermes -p $role skills install $ponytail_url)${NC}"
    fi
  done

  echo ""
}

# ============================================================================
# Phase 5: MCP Installation
# ============================================================================

install_mcps() {
  echo -e "${CYAN}${BOLD}Phase 5: Installing MCP servers${NC}"

  if [ "$DRY_RUN" = true ]; then
    echo "  [dry-run] Would install Context7 + GitHub MCPs"
    return
  fi

  # Context7 for architect + builder
  for role in architect builder; do
    if hermes -p "$role" mcp list 2>/dev/null | grep -qw "context7"; then
      echo -e "  ${YELLOW}⊘ $role: context7 already configured${NC}"
    else
      hermes -p "$role" mcp add context7 --command "npx" --args "-y @upstash/context7-mcp" 2>/dev/null && \
        echo -e "  ${GREEN}✓ $role: context7 MCP added${NC}" || \
        echo -e "  ${YELLOW}⚠ $role: context7 MCP install failed${NC}"
    fi
  done

  # GitHub MCP for default, vcm, reviewer
  for role in default vcm reviewer; do
    if hermes -p "$role" mcp list 2>/dev/null | grep -qw "github"; then
      echo -e "  ${YELLOW}⊘ $role: github MCP already configured${NC}"
    else
      hermes -p "$role" mcp install github 2>/dev/null && \
        echo -e "  ${GREEN}✓ $role: github MCP installed${NC}" || \
        echo -e "  ${YELLOW}⚠ $role: github MCP install failed (may need GITHUB_PERSONAL_ACCESS_TOKEN)${NC}"
    fi
  done

  echo ""
}

# ============================================================================
# Phase 6: Kanban Board Setup
# ============================================================================

setup_kanban() {
  echo -e "${CYAN}${BOLD}Phase 6: Setting up Kanban board${NC}"

  if [ "$DRY_RUN" = true ]; then
    echo "  [dry-run] Would init Kanban + configure dispatcher"
    return
  fi

  # Initialize board
  hermes kanban init 2>/dev/null && echo -e "  ${GREEN}✓ Kanban board initialized${NC}" || \
    echo -e "  ${YELLOW}⚠ Kanban init failed (may already exist)${NC}"

  # Configure orchestrator settings
  hermes config set kanban.orchestrator_profile default 2>/dev/null
  hermes config set kanban.auto_decompose false 2>/dev/null
  hermes config set kanban.dispatch_in_gateway true 2>/dev/null
  hermes config set kanban.failure_limit 2 2>/dev/null
  hermes config set kanban.max_in_progress 3 2>/dev/null
  hermes config set kanban.max_in_progress_per_profile 1 2>/dev/null

  echo -e "  ${GREEN}✓ Kanban configured: CTO orchestrator, manual decompose, sequential default${NC}"
  echo ""
}

# ============================================================================
# Phase 7: Hooks + Plugin
# ============================================================================

install_hooks_and_plugin() {
  echo -e "${CYAN}${BOLD}Phase 7: Installing hooks + guard plugin${NC}"

  if [ "$DRY_RUN" = true ]; then
    echo "  [dry-run] Would install hooks + rudr9-guard plugin"
    return
  fi

  # Hooks
  local hooks_dir="$HERMES_HOME/hooks"
  mkdir -p "$hooks_dir"

  if [ -d "$hooks_dir/rudr9-long-task" ]; then
    echo -e "  ${YELLOW}⊘ long-task hook already installed${NC}"
  else
    cp -r "$ASSETS_DIR/hooks/rudr9-long-task" "$hooks_dir/"
    echo -e "  ${GREEN}✓ long-task hook installed${NC}"
  fi

  # Plugin
  local plugins_dir="$HERMES_HOME/plugins"
  mkdir -p "$plugins_dir"

  if [ -d "$plugins_dir/rudr9-guard" ]; then
    echo -e "  ${YELLOW}⊘ rudr9-guard plugin already installed${NC}"
  else
    cp -r "$ASSETS_DIR/plugins/rudr9-guard" "$plugins_dir/"
    echo -e "  ${GREEN}✓ rudr9-guard plugin installed${NC}"
  fi

  # Enable plugin
  hermes plugins enable rudr9-guard 2>/dev/null && \
    echo -e "  ${GREEN}✓ rudr9-guard plugin enabled${NC}" || \
    echo -e "  ${YELLOW}⚠ Plugin enable failed (run: hermes plugins enable rudr9-guard)${NC}"

  echo ""
}

# ============================================================================
# Phase 8: Post-Install Verification
# ============================================================================

verify_install() {
  echo -e "${CYAN}${BOLD}Phase 8: Verification${NC}"

  if [ "$DRY_RUN" = true ]; then
    echo "  [dry-run] Would verify all components"
    return
  fi

  local warnings=0

  # Check profiles
  for role in "${PROFILES[@]}"; do
    if hermes profile list 2>/dev/null | grep -qw "$role"; then
      echo -e "  ${GREEN}✓ profile: $role${NC}"
    else
      echo -e "  ${RED}✗ profile: $role missing${NC}"
      warnings=$((warnings + 1))
    fi
  done

  # Check SOUL.md files
  for role in default "${PROFILES[@]}"; do
    local soul="$(profile_path "$role")/SOUL.md"
    if [ -f "$soul" ]; then
      echo -e "  ${GREEN}✓ SOUL.md: $role${NC}"
    else
      echo -e "  ${RED}✗ SOUL.md: $role missing${NC}"
      warnings=$((warnings + 1))
    fi
  done

  # Check Kanban
  if hermes kanban stats &>/dev/null 2>&1; then
    echo -e "  ${GREEN}✓ Kanban board operational${NC}"
  else
    echo -e "  ${YELLOW}⚠ Kanban board not responding${NC}"
    warnings=$((warnings + 1))
  fi

  # Check plugin
  if [ -d "$HERMES_HOME/plugins/rudr9-guard" ]; then
    echo -e "  ${GREEN}✓ rudr9-guard plugin present${NC}"
  else
    echo -e "  ${RED}✗ rudr9-guard plugin missing${NC}"
    warnings=$((warnings + 1))
  fi

  echo ""

  if [ $warnings -gt 0 ]; then
    echo -e "${YELLOW}Verification completed with $warnings warning(s).${NC}"
  else
    echo -e "${GREEN}All components verified.${NC}"
  fi
}

# ============================================================================
# Phase 9: Project Init (optional)
# ============================================================================

init_project() {
  if [ "$WITH_PROJECT" = false ]; then
    return
  fi

  echo -e "${CYAN}${BOLD}Phase 9: Project initialization${NC}"

  if [ "$DRY_RUN" = true ]; then
    echo "  [dry-run] Would create .rudr9/ + AGENTS.md in $(pwd)"
    return
  fi

  mkdir -p .rudr9/phases

  if [ ! -f ./AGENTS.md ]; then
    cp "$ASSETS_DIR/templates/AGENTS.md" ./AGENTS.md
    echo -e "  ${GREEN}✓ AGENTS.md created${NC}"
  else
    echo -e "  ${YELLOW}⊘ AGENTS.md already exists, not overwriting${NC}"
  fi

  if [ ! -f .rudr9/PROJECT.md ]; then
    cp "$ASSETS_DIR/templates/PROJECT.md" .rudr9/PROJECT.md
    echo -e "  ${GREEN}✓ .rudr9/PROJECT.md created${NC}"
  fi

  if [ ! -f .rudr9/STATE.md ]; then
    cp "$ASSETS_DIR/templates/STATE.md" .rudr9/STATE.md
    echo -e "  ${GREEN}✓ .rudr9/STATE.md created${NC}"
  fi

  echo ""
}

# ============================================================================
# Uninstall
# ============================================================================

uninstall() {
  echo -e "${RED}${BOLD}RUDR9 Uninstall${NC}"
  echo ""

  for role in "${PROFILES[@]}"; do
    if hermes profile list 2>/dev/null | grep -qw "$role"; then
      echo -e "  ${YELLOW}Removing profile: $role${NC}"
      hermes profile delete "$role" --yes 2>/dev/null || true
    fi
  done

  # Remove hooks
  rm -rf "$HERMES_HOME/hooks/rudr9-long-task" 2>/dev/null && \
    echo -e "  ${GREEN}✓ Removed long-task hook${NC}" || true

  # Remove plugin
  rm -rf "$HERMES_HOME/plugins/rudr9-guard" 2>/dev/null && \
    echo -e "  ${GREEN}✓ Removed rudr9-guard plugin${NC}" || true

  # Reset default profile SOUL.md (backup first)
  if [ -f "$HERMES_HOME/SOUL.md" ]; then
    mv "$HERMES_HOME/SOUL.md" "$HERMES_HOME/SOUL.md.rudr9-backup" 2>/dev/null && \
      echo -e "  ${GREEN}✓ Default SOUL.md backed up to SOUL.md.rudr9-backup${NC}" || true
  fi

  # Reset kanban config
  hermes config set kanban.auto_decompose true 2>/dev/null || true
  hermes config set kanban.orchestrator_profile "" 2>/dev/null || true

  echo ""
  echo -e "${GREEN}RUDR9 uninstalled. Kanban board data preserved (run 'hermes kanban gc' to clean).${NC}"
}

# ============================================================================
# Parse Args + Main
# ============================================================================

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --dry-run)    DRY_RUN=true; shift ;;
      --with-project) WITH_PROJECT=true; shift ;;
      --uninstall)  UNINSTALL=true; shift ;;
      --help|-h)
        echo "RUDR9 Installer — transforms Hermes Agent into a 9-role AI engineering org"
        echo ""
        echo "Usage: ./install.sh [options]"
        echo ""
        echo "Options:"
        echo "  --dry-run       Show what would happen, change nothing"
        echo "  --with-project  Also init .rudr9/ + AGENTS.md in current directory"
        echo "  --uninstall     Remove all RUDR9 profiles, hooks, plugins"
        echo "  --help          Show this help"
        exit 0
        ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done
}

main() {
  parse_args "$@"
  resolve_assets

  if [ "$UNINSTALL" = true ]; then
    uninstall
    exit 0
  fi

  preflight
  create_profiles
  install_souls
  configure_toolsets
  install_skills
  install_mcps
  setup_kanban
  install_hooks_and_plugin
  verify_install
  init_project

  echo ""
  echo -e "${GREEN}${BOLD}🚀 RUDR9 is ready.${NC}"
  echo ""
  echo "  Your AI engineering organization is operational."
  echo "  7 specialist profiles + Default (CTO) are configured."
  echo ""
  echo "  Next steps:"
  echo "    1. Start the gateway:  hermes gateway start"
  echo "    2. Submit a feature request to the Default (CTO) profile"
  echo "    3. Monitor the board: hermes kanban list"
  echo ""
  echo "  CTO will analyze scope, create tasks, and the team will execute."
}

main "$@"