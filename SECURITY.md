# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.0.x | ✅ |
| < 1.0 | ❌ |

## Reporting a Vulnerability

If you discover a security vulnerability in RUDR9, please report it
responsibly.

**Do NOT open a public GitHub issue for security vulnerabilities.**

Instead, please:

1. Email: **security@ardhastudios.com**
2. Include a description of the vulnerability
3. Include steps to reproduce (if possible)
4. Include the potential impact

You will receive a response within **48 hours**.

Please do not disclose the vulnerability publicly until a fix has been
released.

## Disclosure Policy

- We acknowledge receipt of your report within 48 hours
- We investigate and confirm the vulnerability
- We develop and test a fix
- We release a patch release
- We publish a security advisory (if applicable)
- We publicly credit the reporter (if desired)

## Security Measures

RUDR9 implements the following security practices:

- **Per-profile toolset restrictions** — roles physically lack tools to violate their authority boundaries
- **rudr9-guard plugin** — runtime tool-call interception blocking unauthorized actions
- **No secrets in the repository** — API keys are prompted during install and stored in per-profile `.env` files
- **Installer runs with `set -euo pipefail`** — fails fast on errors, no silent partial installs

## Scope

**In scope:**
- Vulnerabilities in the RUDR9 installer, guard plugin, hooks, or templates
- Authority enforcement bypass (e.g., a role accessing tools it shouldn't)
- Secret exposure in the installation process

**Out of scope:**
- Vulnerabilities in Hermes Agent itself (report to [Nous Research](https://github.com/NousResearch/hermes-agent))
- Vulnerabilities in third-party dependencies (Ponytail, Context7, GitHub MCP, Graphify)
- Social engineering attacks
- DoS/DDoS attacks