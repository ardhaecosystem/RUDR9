"""RUDR9 Guard Plugin — enforces role boundaries at the tool-call level.

Belt + suspenders on top of per-profile toolset restrictions. Even if a
toolset is misconfigured, this plugin catches the violation.
"""

import json
import os
import logging

from .rules import is_allowed

logger = logging.getLogger(__name__)

# Hermes sets HERMES_HOME for the active profile. We derive the profile name
# from the path — the last segment of HERMES_HOME is the profile name.
# For the default profile HERMES_HOME ends with ".hermes" → profile "default".


def _get_profile() -> str:
    """Identify the active profile. Hermes sets HERMES_PROFILE when spawning
    workers (see kanban_db.py:8165). Fall back to 'default' if unset."""
    return os.environ.get("HERMES_PROFILE", "default")


def on_pre_tool_call(tool_name: str, params: dict, **kwargs):
    """Hook: runs before any tool executes. Return dict to block."""
    profile = _get_profile()
    if not is_allowed(profile, tool_name):
        logger.warning("RUDR9 guard blocked %s for profile %s", tool_name, profile)
        return {
            "block": True,
            "reason": f"RUDR9: role '{profile}' cannot use '{tool_name}'. Escalate if needed.",
        }
    return None  # allow


def register(ctx):
    ctx.register_hook("pre_tool_call", on_pre_tool_call)