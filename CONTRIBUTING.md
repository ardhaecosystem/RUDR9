# Contributing to RUDR9

Thanks for your interest in contributing! This document covers everything you need to get started.

## Quick Start

1. **Fork** the repository
2. **Clone** your fork: `git clone https://github.com/ArdhaStudios/RUDR9.git`
3. **Add upstream**: `git remote add upstream https://github.com/ArdhaStudios/RUDR9.git`
4. **Create a branch**: `git checkout -b feat/your-feature`
5. **Make changes**, **test**, **commit**
6. **Push**: `git push -u origin HEAD`
7. **Open a Pull Request**

## Development Setup

```bash
git clone https://github.com/ArdhaStudios/RUDR9.git
cd RUDR9

# Test the installer (dry-run, no changes)
./install.sh --dry-run

# Test guard plugin rules
cd assets/plugins/rudr9-guard
python3 -c "
import sys; sys.path.insert(0, '.')
from rules import is_allowed
# Quick smoke test
assert not is_allowed('planner', 'write_file')
assert is_allowed('builder', 'write_file')
assert not is_allowed('security', 'terminal')
print('All assertions passed')
"
```

## What to Contribute

- **New SOUL.md roles** — additional specialist profiles (e.g., DevOps Engineer, Data Scientist)
- **Installer improvements** — better error handling, new platform support, rollback
- **Guard plugin rules** — refined tool permissions, new role mappings
- **Skills** — role-specific skills (planning templates, security checklists, etc.)
- **Hooks** — additional lifecycle monitoring (cost tracking, progress notifications)
- **Documentation** — translations, tutorials, examples

## Branch Naming

Use conventional prefixes:

| Type | Format | Example |
|------|--------|---------|
| Feature | `feat/description` | `feat/add-devops-role` |
| Bug fix | `fix/description` | `fix/installer-profile-detection` |
| Docs | `docs/description` | `docs/update-install-guide` |
| Refactor | `refactor/description` | `refactor/guard-rules-engine` |

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): short description

Optional body explaining what and why.
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `ci`, `chore`, `perf`

Examples:
```
feat(guard): add devops role to allowed tools map
fix(installer): handle missing npx gracefully
docs(readme): add RUDR9 vs PAUL comparison table
```

## Pull Requests

- Keep PRs **small and focused** — one role, one fix, or one feature per PR
- Reference the issue: `Closes #123`
- Use the PR template (auto-surfaces when you create a PR)
- Test your changes: `./install.sh --dry-run` must pass
- Respond to review feedback promptly

### PR Checklist

- [ ] `./install.sh --dry-run` passes
- [ ] Guard plugin rules validated (if changed)
- [ ] Documentation updated if needed
- [ ] Commit messages follow Conventional Commits
- [ ] No merge conflicts with main

## Reporting Issues

- **Search first** — avoid duplicates
- Use the issue templates (Bug Report or Feature Request)
- Include:
  - Hermes Agent version (`hermes --version`)
  - OS and Node.js version
  - Steps to reproduce
  - Expected vs actual behavior
  - Logs (if applicable)

## Code Style

- **Bash** (installer): `set -euo pipefail`, clear error messages, idempotent operations
- **Python** (plugin/hooks): type hints preferred, handlers return JSON strings, never raise — catch and return error JSON
- **Markdown** (SOULs/docs): concise, structured, no fluff

## Testing

The guard plugin has inline tests. Run them before pushing:

```bash
cd assets/plugins/rudr9-guard
python3 -c "
import sys; sys.path.insert(0, '.')
from rules import is_allowed
tests = [
    ('planner', 'write_file', False),
    ('planner', 'read_file', True),
    ('builder', 'write_file', True),
    ('security', 'terminal', False),
    ('vcm', 'terminal', True),
    ('default', 'write_file', False),
]
for profile, tool, expected in tests:
    result = is_allowed(profile, tool)
    assert result == expected, f'{profile}/{tool}: expected {expected}, got {result}'
print(f'{len(tests)} tests passed')
"
```

## Questions?

- Open a discussion (if enabled)
- Open an issue with the `question` label
- Contact: [Ardha Studios](https://github.com/ArdhaStudios)

## Code of Conduct

By participating, you agree to abide by the [Code of Conduct](CODE_OF_CONDUCT.md).